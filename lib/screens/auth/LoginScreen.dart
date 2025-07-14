import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/screens/HomePage.dart';
import 'package:casa/screens/termsAndPrivacy/TermsAndPrivacyPage.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../widgets/SnackbarHelper.dart';

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
  final Color textColor = Colors.black87; // Couleur de texte principale
  final Color secondaryTextColor = Colors.grey[700]!; // Couleur de texte secondaire

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fond blanc
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.05), // Plus clair pour fond blanc
              ),
            ).animate().fadeIn(delay: 100.ms),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.05), // Plus clair pour fond blanc
              ),
            ).animate().fadeIn(delay: 300.ms),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  SizedBox(height: 40),
                  _buildAuthForm(),
                  SizedBox(height: 30),
                  _buildAuthButton(),
                  SizedBox(height: 20),
                  _buildAlternativeAuth(),
                  SizedBox(height: 20),
                  _buildPrivacyText(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentColor, primaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.1), // Ombre plus subtile
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Icon(Icons.home, size: 40, color: Colors.white),
            ).animate().scale(delay: 500.ms, duration: 800.ms),
            SizedBox(width: 10),
            Text('Yinzo', style: TextStyle(
              color: textColor, // Texte sombre pour fond clair
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            )).animate().fadeIn(delay: 700.ms),
          ],
        ),
        SizedBox(height: 10,),
        Text('Trouvez votre maison idéale', style: TextStyle(
          color: secondaryTextColor, // Texte gris foncé
          fontSize: 14,
        )).animate().fadeIn(delay: 900.ms),
      ],
    );
  }

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildEmailField(),
          SizedBox(height: 20),
          _buildPasswordField(),
          SizedBox(height: 10),
          _buildForgotPassword(),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      autovalidateMode: AutovalidateMode.onUserInteraction, // Ajouté
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: 'Email ou Téléphone',
        labelStyle: TextStyle(color: secondaryTextColor),
        prefixIcon: Icon(Icons.email, color: secondaryTextColor),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor),
        ),
        errorBorder: OutlineInputBorder( // Style pour l'état d'erreur
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder( // Style pour l'état d'erreur focalisé
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        hintText: '0854434000',
      ),
      keyboardType: TextInputType.emailAddress,
      onChanged: (_) {
        // Force la revalidation à chaque changement de texte
        if (Form.of(context) != null) {
          Form.of(context)!.validate();
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer votre email ou téléphone';
        }

        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        final phoneRegex = RegExp(r'^(?:(?:\+|00)33|0)\s*[1-9](?:[\s.-]*\d{2}){4}$');
        final cleanedValue = value.replaceAll(RegExp(r'\s+'), '');

        if (!emailRegex.hasMatch(value) && !phoneRegex.hasMatch(cleanedValue)) {
          return 'Email ou téléphone invalide';
        }
        return null;
      },
    ).animate().slideX(
      begin: -0.5,
      duration: 500.ms,
      delay: 1100.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      style: TextStyle(color: textColor), // Texte sombre
      obscureText: !_showPassword,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: (_) => Form.of(context).validate(),
      decoration: InputDecoration(
        labelText: 'Mot de passe',
        labelStyle: TextStyle(color: secondaryTextColor),
        prefixIcon: Icon(Icons.lock, color: secondaryTextColor),
        suffixIcon: IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility : Icons.visibility_off,
            color: secondaryTextColor,
          ),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        errorBorder: OutlineInputBorder( // Style pour l'état d'erreur
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder( // Style pour l'état d'erreur focalisé
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer votre mot de passe';
        }
        if (value.length < 6) {
          return 'Le mot de passe doit faire au moins 6 caractères';
        }
        return null;
      },
    ).animate().slideX(
      begin: 0.5,
      duration: 500.ms,
      delay: 1300.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {},
        child: Text('Mot de passe oublié ?', style: TextStyle(
          color: primaryColor, // Utilisation de la couleur primaire
          fontSize: 12,
        )),
      ),
    ).animate().fadeIn(delay: 1500.ms);
  }

  Widget _buildAuthButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 3,
          shadowColor: primaryColor.withOpacity(0.3),
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
            : Text('Se connecter', style: TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        )),
      ),
    ).animate().scale(
      delay: 1700.ms,
      duration: 500.ms,
      curve: Curves.easeOutBack,
    );
  }

  Widget _buildAlternativeAuth() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Pas de compte ? ', style: TextStyle(color: secondaryTextColor)),
        TextButton(
          onPressed: () {Navigator.pushNamed(context, Routes.registerRoute);},
          child: Text('Créer un compte', style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          )),
        ),
      ],
    ).animate().fadeIn(delay: 1900.ms);
  }

  Widget _buildPrivacyText() {
    return Column(
      children: [
        Text('En continuant, vous acceptez nos', style: TextStyle(
          color: secondaryTextColor,
          fontSize: 12,
        )),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => TermsAndPrivacyPage(initialTabIndex: 0),
                ));
              },
              child: Text('Conditions', style: TextStyle(
                color: primaryColor,
                fontSize: 12,
              )),
            ),
            Text('et', style: TextStyle(
              color: secondaryTextColor,
              fontSize: 12,
            )),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => TermsAndPrivacyPage(initialTabIndex: 1),
                ));
              },
              child: Text('Politique de confidentialité', style: TextStyle(
                color: primaryColor,
                fontSize: 12,
              )),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, color: primaryColor, size: 16),
            SizedBox(width: 8),
            Text('Données sécurisées', style: TextStyle(
              color: secondaryTextColor,
              fontSize: 12,
            )),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 2100.ms);
  }

  bool get _isFormValid {
    return _emailController.text.isNotEmpty || _passwordController.text.isNotEmpty;
  }


  Future<void> _handleLogin() async {

    if (!(_formKey.currentState?.validate() ?? false)) {
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

    setState(() => _isLoading = true);
    print("MUZOLAAAAAAAAAAA");

    try {


      final userData = {
        "email": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
      };

      final ctrl = context.read<AuthentificationCtrl>();
      print("NOELLLLLLLLLL");
      final res = await ctrl.login(userData);
      print("ALICEEEEEEE");

      if (!mounted) return;

      print("MUZOLAAAAAAAAAAA${res.data}");

      if (res.data['success'] == true) {
        FancyNotification.show(context, "Connexion réussie!", isError: false);
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.bottomPageRoute,
                (route) => false,
          );
        }
      }  else {
        String errorMessage = res.data['message'] ?? "Identifiants incorrects";
        FancyNotification.show(context, errorMessage);
      }
    } catch (e) {
      FancyNotification.show(context, "Erreur technique");
      print("Login error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }






  // void _handleLogin() async {
  //   if (_formKey.currentState!.validate()) {
  //     setState(() => _isLoading = true);
  //
  //     // Simuler un appel réseau
  //     await Future.delayed(Duration(seconds: 2));
  //
  //     setState(() => _isLoading = false);
  //
  //     Navigator.pushReplacement(
  //       context,
  //       PageRouteBuilder(
  //         pageBuilder: (context, animation, secondaryAnimation) => HomePage(),
  //         transitionsBuilder: (context, animation, secondaryAnimation, child) {
  //           return FadeTransition(
  //             opacity: animation,
  //             child: child,
  //           );
  //         },
  //         transitionDuration: Duration(milliseconds: 500),
  //       ),
  //     );
  //   }
  // }
}