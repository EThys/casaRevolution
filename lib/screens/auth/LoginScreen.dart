import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/screens/HomePage.dart';

import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/screens/auth/ForgotPasswordScreen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../utils/FancyNotification.dart';
import '../../utils/api_error_message.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color lightBlue = Color(0xFFE3F2FD);
  final Color textColor = Color(0xFF1A237E);
  final Color errorColor = Color(0xFFD63031);
  final Color secondaryTextColor = Color(0xFF5C6BC0);
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  // bool _acceptConditions removed
  
  // États pour la gestion de la validation
  bool _emailTouched = false;
  bool _passwordTouched = false;

  // États pour le sélecteur de pays
  String _selectedCountryCode = '+243'; // RDC par défaut
  bool _isPhoneInput = false;
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  // Dictionnaire des indicatifs avec drapeaux
  final Map<String, String> _countryFlags = {
    '+243': '🇨🇩', // RDC (toujours en premier)
    '+1': '🇺🇸', // USA
    '+20': '🇪🇬', // Égypte
    '+31': '🇳🇱', // Pays-Bas
    '+32': '🇧🇪', // Belgique
    '+33': '🇫🇷', // France
    '+34': '🇪🇸', // Espagne
    '+39': '🇮🇹', // Italie
    '+41': '🇨🇭', // Suisse
    '+44': '🇬🇧', // UK
    '+45': '🇩🇰', // Danemark
    '+46': '🇸🇪', // Suède
    '+47': '🇳🇴', // Norvège
    '+49': '🇩🇪', // Allemagne
    '+212': '🇲🇦', // Maroc
    '+213': '🇩🇿', // Algérie
    '+216': '🇹🇳', // Tunisie
    '+221': '🇸🇳', // Sénégal
    '+225': '🇨🇮', // Côte d'Ivoire
    '+226': '🇧🇫', // Burkina Faso
    '+229': '🇧🇯', // Bénin
    '+233': '🇬🇭', // Ghana
    '+234': '🇳🇬', // Nigeria
    '+242': '🇨🇬', // Congo Brazzaville
    '+251': '🇪🇹', // Éthiopie
    '+254': '🇰🇪', // Kenya
    '+255': '🇹🇿', // Tanzanie
    '+258': '🇲🇿', // Mozambique
    '+260': '🇿🇲', // Zambie
    '+351': '🇵🇹', // Portugal
  };

  @override
  void initState() {
    super.initState();

    // Ajouter des listeners pour tous les contrôleurs
    _emailController.addListener(_updateButtonState);
    _passwordController.addListener(_updateButtonState);

    // Listeners pour les focus nodes
    _emailFocusNode.addListener(_onEmailFocusChange);
    _passwordFocusNode.addListener(_onPasswordFocusChange);
  }

  void _onEmailFocusChange() {
    if (!_emailFocusNode.hasFocus && _emailController.text.isNotEmpty) {
      setState(() {
        _emailTouched = true;
      });
    }
  }

  void _onPasswordFocusChange() {
    if (!_passwordFocusNode.hasFocus && _passwordController.text.isNotEmpty) {
      setState(() {
        _passwordTouched = true;
      });
    }
  }

  // Nouvelle méthode pour mettre à jour l'état du bouton
  void _updateButtonState() {
    if (mounted) {
      setState(() {
        // Détecter si l'utilisateur saisit un numéro de téléphone
        final text = _emailController.text.trim();
        _isPhoneInput = _looksLikePhoneNumber(text);
      });
    }
  }
  bool _looksLikePhoneNumber(String text) {
    if (text.isEmpty) return false;

    // Si commence par un + ou un chiffre, ou ne contient pas @ et a des chiffres
    final hasDigits = RegExp(r'\d').hasMatch(text);
    final hasAtSymbol = text.contains('@');
    final startsWithPlus = text.startsWith('+');
    final startsWithDigit = text.isNotEmpty && RegExp(r'^\d').hasMatch(text);

    return hasDigits && !hasAtSymbol && (startsWithPlus || startsWithDigit || text.length >= 8);
  }

  @override
  void dispose() {
    _emailController.removeListener(_updateButtonState);
    _passwordController.removeListener(_updateButtonState);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Arrière-plan avec éléments décoratifs
          _buildBackground(),

          // Contenu principal
          AbsorbPointer(
            absorbing: _isLoading,
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 24),
              child: SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios, color: textColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildLogo(),
                    SizedBox(height: 30),
                    _buildAuthCard(),
                    SizedBox(height: 10)
                  ],
                ),
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
                'Trouvez votre maison idéale',
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
            'Connexion',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ).animate().fadeIn(delay: 1100.ms),

          SizedBox(height: 10),

          Text(
            'Content de vous revoir !',
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 14,
            ),
          ).animate().fadeIn(delay: 1200.ms),

          SizedBox(height: 30),

                _buildAuthForm(),
                SizedBox(height: 25),
                // _buildPrivacyText() removed
                _buildAuthButton(),
                SizedBox(height: 10),
                _buildForgotPassword(),
                _buildAlternativeAuth(),
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
          _buildEmailField(),
          SizedBox(height: 20),
          _buildPasswordField(),
        ],
      ),
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
        focusNode: _emailFocusNode,
        autovalidateMode: AutovalidateMode.disabled,
        style: TextStyle(color: Colors.black87, fontSize: 16), // Force black text on light background
        textInputAction: TextInputAction.next, // ← AJOUTER CETTE LIGNE
        decoration: InputDecoration(
          labelText: 'Email ou Téléphone',
          labelStyle: TextStyle(color: Colors.black87), // Force black label on light background
          prefixIcon: _isPhoneInput && _emailController.text.isNotEmpty
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
          errorText: _emailTouched ? _validateEmail(_emailController.text) : null,
        ),
        keyboardType: _isPhoneInput ? TextInputType.phone : TextInputType.emailAddress,
        onChanged: (String value) {
          if (!_emailTouched && value.isNotEmpty) {
            setState(() => _emailTouched = true);
          }
          // Gérer automatiquement le 0 initial pour les numéros de téléphone
          bool isPhone = _looksLikePhoneNumber(value);
          if (isPhone) {
            String cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
            if (cleaned.startsWith('0') && cleaned.length > 1) {
              // Supprimer le 0 et garder les chiffres suivants
              cleaned = cleaned.substring(1);
              _emailController.value = TextEditingValue(
                text: cleaned,
                selection: TextSelection.collapsed(offset: cleaned.length),
              );
              // Mettre à jour l'état après modification
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateButtonState();
                _forceRevalidation();
              });
              return; // Sortir pour éviter le setState double
            }
          }
          _updateButtonState();
          _forceRevalidation();
        },
        onEditingComplete: () {
          // Vérifier si l'email est valide avant de passer au suivant
          final emailError = _validateEmail(_emailController.text);
          if (emailError == null) {
            FocusScope.of(context).requestFocus(_passwordFocusNode);
          } else {
            // Garder le focus sur l'email s'il y a une erreur
            _emailFocusNode.requestFocus();
          }
          setState(() {
            _emailTouched = true;
          });
        },
        validator: null,
      ),
    ).animate().slideX(
      begin: -0.3,
      duration: 500.ms,
      delay: 1300.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildCountryCodeDropdown() {
    return Container(
      width: 120,
      padding: EdgeInsets.only(left: 8, right: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCountryCode,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down_rounded, color: primaryColor, size: 20),
          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
          items: _countryFlags.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.value, style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text(entry.key, style: TextStyle(fontSize: 13)),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedCountryCode = newValue;
              });
            }
          },
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
        focusNode: _passwordFocusNode,
        style: TextStyle(color: Colors.black87, fontSize: 16), // Force black text on light background
        obscureText: !_showPassword,
        autovalidateMode: AutovalidateMode.disabled,
        textInputAction: TextInputAction.done, // ← AJOUTER CETTE LIGNE
        onChanged: (val) {
          if (!_passwordTouched && val.isNotEmpty) {
            setState(() => _passwordTouched = true);
          }
          _forceRevalidation();
        },
        onEditingComplete: () {
          // Fermer le clavier et valider quand on appuie sur "Done"
          FocusScope.of(context).unfocus();
          setState(() {
            _passwordTouched = true;
          });
          // Déclencher la connexion si les conditions sont remplies
          _triggerLoginIfValid();
        },
        decoration: InputDecoration(
          labelText: 'Mot de passe',
          labelStyle: TextStyle(color: Colors.black87), // Force black label on light background
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.lock_rounded, color: primaryColor),
          ),
          suffixIcon: Container(
            padding: EdgeInsets.all(8),
            child: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: secondaryTextColor,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
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
      delay: 1500.ms,
      curve: Curves.easeOut,
    );
  }

  void _triggerLoginIfValid() {
    final isEmailValid = _validateEmail(_emailController.text) == null;
    final isPasswordValid = _validatePassword(_passwordController.text) == null;
    final hasRequiredFields = _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty;
    final isButtonEnabled = isEmailValid && isPasswordValid && hasRequiredFields && !_isLoading;

    if (isButtonEnabled) {
      _handleLogin();
    }
  }



  Widget _buildAuthButton() {
    final isEmailValid = _validateEmail(_emailController.text) == null;
    final isPasswordValid = _validatePassword(_passwordController.text) == null;
    final hasRequiredFields = _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty;
    final isButtonEnabled = isEmailValid && isPasswordValid && hasRequiredFields && !_isLoading;

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
        onPressed: isButtonEnabled ? _handleLogin : null,
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
              'Se connecter',
              style: TextStyle(
                fontSize: 16,
                color: isButtonEnabled ? Colors.white : Colors.white.withOpacity(0.7), // ← CHANGÉ: texte légèrement transparent si désactivé
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: isButtonEnabled ? Colors.white : Colors.white.withOpacity(0.7), // ← CHANGÉ: icône légèrement transparente si désactivé
            ),
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

  Widget _buildForgotPassword() {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
        );
      },
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(
        'Mot de passe oublié ?',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ).animate().fadeIn(delay: 2000.ms);
  }

  Widget _buildAlternativeAuth() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'Pas de compte ? ',
            style: TextStyle(
              color: primaryColor,
              fontSize: 13,
            ),
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, Routes.registerRoute);
            },
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Créer un compte',
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


  void _forceRevalidation() {
    if (mounted) {
      setState(() {});
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre email ou téléphone';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final phoneRegex = RegExp(r'^[\d\s\-\+\(\)]{8,}$');

    // Nettoyer le numéro de téléphone pour la validation
    final cleanedValue = value.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
    final isPhone = _looksLikePhoneNumber(value);

    if (isPhone) {
      // Validation spécifique selon le pays sélectionné
      if (_selectedCountryCode == '+243') {
        // Validation pour la RDC
        if (cleanedValue.length != 9) {
          return 'Le numéro RDC doit avoir 9 chiffres';
        }
        if (!RegExp(r'^[89]').hasMatch(cleanedValue)) {
          return 'Le numéro RDC doit commencer par 8 ou 9';
        }
      } else {
        // Validation générale pour les autres pays
        if (cleanedValue.length < 8) {
          return 'Numéro de téléphone trop court';
        }
        if (!RegExp(r'^\d+$').hasMatch(cleanedValue)) {
          return 'Numéro de téléphone invalide';
        }
      }
    } else {
      if (!emailRegex.hasMatch(value)) {
        return 'Email invalide';
      }
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



  Future<void> _handleLogin() async {
    // Marquer tous les champs comme touchés pour afficher les erreurs
    setState(() {
      _emailTouched = true;
      _passwordTouched = true;
      _autoValidateMode = AutovalidateMode.always;
    });

    await Future.delayed(Duration(milliseconds: 50));

    // VÉRIFICATION DES CONDITIONS SUPPRIMÉE ICI
    
    // Valider les champs
    final emailError = _validateEmail(_emailController.text);
    final passwordError = _validatePassword(_passwordController.text);

    if (emailError != null || passwordError != null) {
      SnackbarForCasa.error(context, "Veuillez corriger les erreurs ci-dessus");
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
      // Préparer l'identifiant en fonction du type (email ou téléphone)
      String identifiant = _emailController.text.trim();

      // MODIFICATION ICI : Si c'est un numéro de téléphone, AJOUTER L'INDICATIF
      if (_isPhoneInput) {
        // Nettoyer le numéro (supprimer les espaces, tirets, etc.) - garder seulement les chiffres
        identifiant = identifiant.replaceAll(RegExp(r'[^\d]'), '');

        // AJOUTER L'INDICATIF AU DÉBUT DU NUMÉRO
        String phoneWithCountryCode;

        // Si le numéro commence par 0 (cas typique), on supprime le 0 avant d'ajouter l'indicatif
        if (identifiant.startsWith('0')) {
          final numberWithoutZero = identifiant.substring(1);
          phoneWithCountryCode = '${_selectedCountryCode}$numberWithoutZero';
        }
        // Vérifier si le numéro contient déjà l'indicatif
        else if (identifiant.startsWith(_selectedCountryCode.replaceAll('+', ''))) {
          // Le numéro a déjà l'indicatif, on ajoute juste le '+'
          phoneWithCountryCode = '+$identifiant';
        }
        // Vérifier si c'est un numéro RDC (commence par 8 ou 9 et fait 9 chiffres)
        else if ((identifiant.startsWith('8') || identifiant.startsWith('9')) && identifiant.length == 9) {
          // C'est un numéro RDC sans indicatif, on ajoute +243
          phoneWithCountryCode = '${_selectedCountryCode}$identifiant';
        }
        else {
          // Autres cas : on ajoute l'indicatif tel quel
          phoneWithCountryCode = '${_selectedCountryCode}$identifiant';
        }

        identifiant = phoneWithCountryCode; // ← UTILISER LE NUMÉRO AVEC INDICATIF
      }

      final userData = {
        "identifiant": identifiant, // ← Maintenant avec indicatif si c'est un téléphone
        "password": _passwordController.text.trim(),
      };

      final ctrl = context.read<AuthentificationCtrl>();
      final res = await ctrl.login(userData);

      if (!mounted) return;
      String message = res.data['message']?.toString() ?? '';
      bool isSuccess = message.toLowerCase().contains('réussie');

      if (isSuccess) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.bottomPageRoute,
                (route) => false,
          );
        }
      } else {
        final rawError = res.data is Map
            ? (res.data['message']?.toString() ?? '')
            : '';
        print("Login error: $rawError");

        if (rawError.contains("Idenfiant invalide.")) {
          SnackbarForCasa.error(context, "Ce numéro ne correspond à aucun compte dans CasaNayo. Veuillez d'abord créer un compte.");
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushNamed(context, Routes.registerRoute);
          }
          return;
        }

        final errorMsg = ApiErrorMessages.fromResponse(res);
        SnackbarForCasa.error(context, errorMsg);
      }
    } catch (e) {
      print("Login error: $e");
      // Ne pas afficher les erreurs techniques
      SnackbarForCasa.error(context, "Une erreur est survenue lors de la connexion. Veuillez réessayer.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}