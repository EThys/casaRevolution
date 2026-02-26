import 'package:casa/controllers/ForgotPasswordController.dart';
import 'package:casa/screens/auth/ResetPasswordScreen.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';
import '../../utils/FancyNotification.dart';
import '../../utils/ModernModal.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OTPVerificationScreen({required this.phoneNumber});

  @override
  _OTPVerificationScreenState createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> with CodeAutoFill {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  bool _isHandlingPaste = false;
  int _countdown = 60;
  int _resendAttempts = 0;
  final int maxAttempts = 3; // Limite de 3 tentatives par numéro
  final int maxDeviceDailyRequests = 10; // Limite globale du téléphone par jour
  final box = GetStorage();
  
  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color lightBlue = Color(0xFFE3F2FD);
  final Color textColor = Color(0xFF1A237E);
  final Color errorColor = Color(0xFFD63031);
  final Color secondaryTextColor = Color(0xFF5C6BC0);

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _initSmsAutoFill();
    _loadAttempts();
    // Auto focus sur le premier champ
    Future.delayed(Duration(milliseconds: 300), () {
      _focusNodes[0].requestFocus();
    });
  }

  void _loadAttempts() {
    // Charger le nombre de tentatives sauvegardées pour ce numéro
    String key = 'otp_attempts_${widget.phoneNumber}';
    setState(() {
      _resendAttempts = box.read(key) ?? 0;
    });
  }

  void _initSmsAutoFill() async {
    listenForCode();
    // Récupérer la signature de l'application pour Android
    // IMPORTANT: Affichez ceci dans vos logs et ajoutez-le à la fin de votre SMS
    // pour que l'auto-remplissage fonctionne sur Android.
    String signature = await SmsAutoFill().getAppSignature;
    print("Code App Signature pour le SMS (Android): $signature");
  }

  @override
  void codeUpdated() {
    // Cette méthode est appelée quand un SMS OTP est détecté
    if (code != null) {
      // Extraire les 6 chiffres du code
      String otp = code!.replaceAll(RegExp(r'[^0-9]'), '');
      if (otp.length >= 6) {
        String finalOtp = otp.substring(0, 6);
        setState(() {
          for (int i = 0; i < 6; i++) {
            _controllers[i].text = finalOtp[i];
          }
        });
        _handleVerifyOTP(); // Tenter la vérification automatique
      }
    }
  }

  void _startCountdown() {
    Future.delayed(Duration(seconds: 1), () {
      if (mounted && _countdown > 0) {
        setState(() {
          _countdown--;
        });
        _startCountdown();
      }
    });
  }

  @override
  void dispose() {
    cancel(); // Arrêter l'écoute du SMS
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (_isHandlingPaste) return;

    if (value.length > 1) {
      _isHandlingPaste = true;
      // Nettoyer la valeur pour n'avoir que des chiffres
      String code = value.replaceAll(RegExp(r'[^0-9]'), '');
      
      // Distribuer les chiffres
      for (int i = 0; i < code.length && (index + i) < 6; i++) {
        _controllers[index + i].text = code[i];
        _controllers[index + i].selection = TextSelection.fromPosition(
          TextPosition(offset: _controllers[index + i].text.length),
        );
      }
      _isHandlingPaste = false;

      // Déplacer le focus
      int nextIndex = index + code.length;
      if (nextIndex >= 6) {
        _focusNodes[5].unfocus();
      } else {
        _focusNodes[nextIndex].requestFocus();
      }
    } else if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    
    // Vérifier si tous les champs sont remplis
    if (_getOTPCode().length == 6) {
      _handleVerifyOTP();
    }
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String _getOTPCode() {
    return _controllers.map((controller) => controller.text).join();
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
          _buildBackground(),
          PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldPop = await _showExitConfirmation();
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            },
            child: SafeArea(
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
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
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
                'Vérification du code',
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
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
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
            'Code de vérification',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ).animate().fadeIn(delay: 1100.ms),
          SizedBox(height: 10),
          Text(
            'Nous avons envoyé un code à 6 chiffres au',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 14,
            ),
          ).animate().fadeIn(delay: 1200.ms),
          SizedBox(height: 5),
          Text(
            widget.phoneNumber,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 1200.ms),
          SizedBox(height: 30),
          _buildOTPFields(),
          if (_resendAttempts > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Tentatives de renvoi : $_resendAttempts / $maxAttempts',
                style: TextStyle(
                  fontSize: 12,
                  color: _resendAttempts >= maxAttempts ? errorColor : secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          SizedBox(height: 25),
          _buildVerifyButton(),
          SizedBox(height: 20),
          _buildResendCode(),
        ],
      ),
    ).animate().slideY(
      begin: 0.5,
      duration: 600.ms,
      delay: 1000.ms,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildOTPFields() {
    return AutofillGroup(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (index) {
          return Flexible(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 2),
              height: 60,
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
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6, // Augmenté pour supporter le paste
                autofillHints: const [AutofillHints.oneTimeCode],
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: lightBlue.withOpacity(0.3),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (value) => _onChanged(index, value),
                onTap: () {
                  _controllers[index].selection = TextSelection.fromPosition(
                    TextPosition(offset: _controllers[index].text.length),
                  );
                },
                onSubmitted: (_) {
                  if (index < 5) {
                    _focusNodes[index + 1].requestFocus();
                  } else {
                    _handleVerifyOTP();
                  }
                },
              ),
            ),
          ).animate()
              .scale(delay: (1300 + index * 100).ms, duration: 400.ms);
        }),
      ),
    );
  }

  Widget _buildVerifyButton() {
    final isOTPComplete = _controllers.every((controller) => controller.text.isNotEmpty);
    final isButtonEnabled = isOTPComplete && !_isLoading;

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
        onPressed: isButtonEnabled ? _handleVerifyOTP : null,
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
              'Vérifier',
              style: TextStyle(
                fontSize: 16,
                color: isButtonEnabled ? Colors.white : Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 10),
            Icon(
              Icons.check_circle_rounded,
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

  Widget _buildResendCode() {
    return Column(
      children: [
        if (_countdown > 0)
          Text(
            'Renvoyer le code dans ${_countdown}s',
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 14,
            ),
          )
        else
          TextButton(
            onPressed: (_isResending || _resendAttempts >= maxAttempts) ? null : _handleResendCode,
            style: TextButton.styleFrom(
              foregroundColor: (_resendAttempts >= maxAttempts) ? Colors.grey : primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: _isResending
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(primaryColor),
              ),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 18),
                SizedBox(width: 8),
                Text(
                  _resendAttempts >= maxAttempts ? 'Limite atteinte' : 'Renvoyer le code',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleVerifyOTP() async {
    final otpCode = _getOTPCode();
    
    if (otpCode.length != 6) {
      SnackbarForCasa.error(context, "Veuillez entrer le code complet");
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
      final ctrl = context.read<ForgotPasswordController>();
      final res = await ctrl.verifyOTP(widget.phoneNumber, otpCode);

      if (!mounted) return;

      if (res.status == true && res.data != null) {
        // Vérifier la structure de la réponse
        final responseData = res.data as Map<String, dynamic>;
        final status = responseData['status'] as String?;
        
        if (status == "approved" && ctrl.userId != null) {
          SnackbarForCasa.success(context, "Code vérifié avec succès");
          
          // Naviguer vers la page de réinitialisation du mot de passe avec l'ID utilisateur
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(
                userId: ctrl.userId!,
              ),
            ),
          );
        } else {
          // Status différent de "approved" = code expiré
          SnackbarForCasa.error(context, "Code expiré ou invalide");
          
          // Effacer les champs en cas d'erreur
          for (var controller in _controllers) {
            controller.clear();
          }
          _focusNodes[0].requestFocus();
        }
      } else {
        String errorMessage = res.errorMsg ?? "Code OTP invalide";
        if (res.data != null && res.data is Map) {
          errorMessage = (res.data as Map)['message'] ?? errorMessage;
        }
        
        // Gestion professionnelle de l'erreur 500 (souvent due à un code déjà utilisé)
        if (errorMessage.toLowerCase().contains("internal server error") || 
            errorMessage.contains("500") || 
            (res.errorMsg != null && res.errorMsg!.contains("500"))) {
          errorMessage = "Ce code est invalide ou a déjà été utilisé. Veuillez en demander un nouveau si nécessaire.";
        }
        
        SnackbarForCasa.error(context, errorMessage);
        
        // Effacer les champs en cas d'erreur
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      String errorMsg = "Erreur technique lors de la vérification";
      if (e.toString().toLowerCase().contains("internal server error") || 
          e.toString().contains("500")) {
        errorMsg = "Ce code est invalide ou a déjà été utilisé.";
      }
      SnackbarForCasa.error(context, errorMsg);
      print("OTP verification error: $e");
      
      // Effacer les champs en cas d'erreur
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResendCode() async {
    if (!mounted || _isResending || _resendAttempts >= maxAttempts) return;
    
    // Vérifier la limite globale de l'appareil
    int globalCount = box.read('global_otp_count') ?? 0;
    if (globalCount >= maxDeviceDailyRequests) {
      SnackbarForCasa.error(context, "Limite quotidienne atteinte pour cet appareil.");
      return;
    }

    setState(() {
      _isResending = true;
    });

    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      SnackbarForCasa.error(context, "Pas de connexion internet");
      setState(() => _isResending = false);
      return;
    }

    try {
      final ctrl = context.read<ForgotPasswordController>();
      final res = await ctrl.generateOTP(widget.phoneNumber);

      if (!mounted) return;

      if (res.status == true && res.data != null) {
        setState(() {
          _resendAttempts++;
          _countdown = 60;
          // Sauvegarder les tentatives par numéro
          box.write('otp_attempts_${widget.phoneNumber}', _resendAttempts);
          
          // Incrémenter et sauvegarder le compteur global de l'appareil
          int currentGlobalCount = box.read('global_otp_count') ?? 0;
          box.write('global_otp_count', currentGlobalCount + 1);
        });
        
        final responseData = res.data as Map<String, dynamic>;
        final message = responseData['message'] ?? "Code OTP renvoyé avec succès";
        SnackbarForCasa.success(context, message);
        _startCountdown();
      } else {
        String errorMessage = res.data != null && res.data is Map
            ? (res.data as Map)['message'] ?? "Erreur lors de l'envoi du code"
            : res.errorMsg ?? "Erreur lors de l'envoi du code";
            
        // Gestion professionnelle de l'erreur 500
        if (errorMessage.toLowerCase().contains("internal server error") || 
            errorMessage.contains("500") || 
            (res.errorMsg != null && res.errorMsg!.contains("500"))) {
          errorMessage = "Le service d'envoi est momentanément indisponible. Veuillez réessayer.";
        }
        
        SnackbarForCasa.error(context, errorMessage);
      }
    } catch (e) {
      SnackbarForCasa.error(context, "Erreur technique lors de l'envoi du code");
      print("Resend OTP error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<bool> _showExitConfirmation() async {
    bool result = false;
    await ModernModal.showConfirm(
      context: context,
      title: 'Quitter la vérification ?',
      message: 'Voulez-vous vraiment annuler la vérification du code OTP ?',
      actionLabel: 'Quitter',
      secondaryLabel: 'Rester',
      isDestructive: true,
      onConfirm: () {
        result = true;
      },
      onCancel: () {
        result = false;
      },
    );
    return result; 
  }
}

