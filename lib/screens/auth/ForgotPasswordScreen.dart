import 'package:casa/controllers/ForgotPasswordController.dart';
import 'package:casa/screens/auth/OTPVerificationScreen.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../utils/FancyNotification.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color lightBlue = Color(0xFFE3F2FD);
  final Color textColor = Color(0xFF1A237E);
  final Color errorColor = Color(0xFFD63031);
  final Color secondaryTextColor = Color(0xFF5C6BC0);
  bool _phoneTouched = false;
  String _selectedCountryCode = '+243';

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
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Arrière-plan avec éléments décoratifs
          _buildBackground(),

          // Contenu principal
          SafeArea(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 24),
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
              child: Container(
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
            ),
          ],
        ).animate()
            .scale(delay: 500.ms, duration: 800.ms, curve: Curves.elasticOut),

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
                'Réinitialisation du mot de passe',
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
            'Mot de passe oublié ?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ).animate().fadeIn(delay: 1100.ms),

          SizedBox(height: 10),

          Text(
            'Entrez votre numéro de téléphone pour recevoir un code de vérification',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 14,
            ),
          ).animate().fadeIn(delay: 1200.ms),

          SizedBox(height: 30),

          _buildPhoneForm(),
          SizedBox(height: 25),
          _buildSendButton(),
        ],
      ),
    ).animate().slideY(
      begin: 0.5,
      duration: 600.ms,
      delay: 1000.ms,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildPhoneForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildPhoneField(),
        ],
      ),
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
        style: TextStyle(color: textColor, fontSize: 16),
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
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
          setState(() {
            if (!_phoneTouched) {
              _phoneTouched = true;
            }
          });
        },
        onEditingComplete: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _phoneTouched = true;
          });
        },
        decoration: InputDecoration(
          labelText: 'Numéro de téléphone',
          labelStyle: TextStyle(color: secondaryTextColor),
          prefixIcon: _buildCountryCodeDropdown(),
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

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre numéro de téléphone';
    }

    final cleanedValue = value.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');

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

    return null;
  }

  Widget _buildSendButton() {
    // Pour le Congo (+243), activer le bouton dès que 9 chiffres sont entrés
    String cleanedPhone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    bool hasEnoughDigits = false;
    if (_selectedCountryCode == '+243') {
      hasEnoughDigits = cleanedPhone.length >= 9;
    } else {
      hasEnoughDigits = cleanedPhone.length >= 8;
    }
    
    final isPhoneValid = _validatePhone(_phoneController.text) == null;
    final hasPhone = _phoneController.text.isNotEmpty;
    final isButtonEnabled = (isPhoneValid || hasEnoughDigits) && hasPhone && !_isLoading;

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
        onPressed: isButtonEnabled ? _handleForgotPassword : null,
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
              'Envoyer le code',
              style: TextStyle(
                fontSize: 16,
                color: isButtonEnabled ? Colors.white : Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: isButtonEnabled ? Colors.white : Colors.white.withOpacity(0.7),
            ),
          ],
        ),
      ),
    ).animate().scale(
      delay: 1900.ms,
      duration: 500.ms,
    );
  }

  Future<void> _handleForgotPassword() async {
    setState(() {
      _phoneTouched = true;
    });

    await Future.delayed(Duration(milliseconds: 50));

    final phoneError = _validatePhone(_phoneController.text);

    if (phoneError != null) {
      SnackbarForCasa.error(context, phoneError);
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
      String phoneNumber = _phoneController.text.trim();
      phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Formater le numéro avec l'indicatif
      String phoneWithCountryCode;
      if (phoneNumber.startsWith('0')) {
        final numberWithoutZero = phoneNumber.substring(1);
        phoneWithCountryCode = '${_selectedCountryCode}$numberWithoutZero';
      } else if (phoneNumber.startsWith(_selectedCountryCode.replaceAll('+', ''))) {
        phoneWithCountryCode = '+$phoneNumber';
      } else if ((phoneNumber.startsWith('8') || phoneNumber.startsWith('9')) && phoneNumber.length == 9) {
        phoneWithCountryCode = '${_selectedCountryCode}$phoneNumber';
      } else {
        phoneWithCountryCode = '${_selectedCountryCode}$phoneNumber';
      }

      final ctrl = context.read<ForgotPasswordController>();
      final res = await ctrl.generateOTP(phoneWithCountryCode);

      if (!mounted) return;

      print("${res.data}MUZOOLLAAAA");

      if (res.data["status"] == "pending" && res.data != null) {
        // Vérifier la structure de la réponse
        final responseData = res.data as Map<String, dynamic>;
        final message = responseData['message'] ?? "Code OTP envoyé avec succès";
        final phone = responseData['phone'] ?? phoneWithCountryCode;
        
        SnackbarForCasa.success(context, message);
        
        // Naviguer vers la page OTP avec le numéro de téléphone de la réponse
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(phoneNumber: phone),
          ),
        );
      } else {
        String errorMessage = res.data != null && res.data is Map
            ? (res.data as Map)['message'] ?? "Erreur lors de l'envoi du code"
            : res.errorMsg ?? "Erreur lors de l'envoi du code";
        print("Forgot password error: $errorMessage");
        // Ne pas afficher les erreurs techniques du serveur
        SnackbarForCasa.error(context, "Une erreur est survenue lors de l'envoi du code. Veuillez vérifier votre numéro et réessayer.");
      }
    } catch (e) {
      print("Forgot password error: $e");
      // Ne pas afficher les erreurs techniques
      SnackbarForCasa.error(context, "Une erreur est survenue lors de l'envoi du code. Veuillez réessayer.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

