import 'package:casa/screens/HomePage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor, darkBlue],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.1),
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
                  color: primaryColor.withOpacity(0.1),
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
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Icon(Icons.home, size: 40, color: Colors.white),
            ).animate().scale(delay: 500.ms, duration: 800.ms),
            SizedBox(width: 10),
            Text('Casa', style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            )).animate().fadeIn(delay: 700.ms),
          ],
        ),
        SizedBox(height: 10,),
        Text('Trouvez votre maison idéale', style: TextStyle(
          color: Colors.white.withOpacity(0.8),
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
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        prefixIcon: Icon(Icons.email, color: Colors.white.withOpacity(0.8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer votre email';
        }
        if (!value.contains('@')) {
          return 'Email invalide';
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
      style: TextStyle(color: Colors.white),
      obscureText: !_showPassword,
      decoration: InputDecoration(
        labelText: 'Mot de passe',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        prefixIcon: Icon(Icons.lock, color: Colors.white.withOpacity(0.8)),
        suffixIcon: IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.white.withOpacity(0.8),
          ),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
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
          color:  Colors.white,
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
          backgroundColor: accentColor,
          foregroundColor: darkBlue,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 5,
          shadowColor: accentColor.withOpacity(0.5),
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
          color:  Colors.white,
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
        Text('Pas de compte ? ', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        TextButton(
          onPressed: () {},
          child: Text('Créer un compte', style: TextStyle(
            color: Colors.white,
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
          color: Colors.white.withOpacity(0.6),
          fontSize: 12,
        )),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              child: Text('Conditions', style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              )),
            ),
            Text(' et ', style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            )),
            TextButton(
              onPressed: () {},
              child: Text('Politique de confidentialité', style: TextStyle(
                color:  Colors.white,
                fontSize: 12,
              )),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, color: accentColor, size: 16),
            SizedBox(width: 8),
            Text('Données sécurisées', style: TextStyle(
              color:  Colors.white,
              fontSize: 12,
            )),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 2100.ms);
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Simuler un appel réseau
      await Future.delayed(Duration(seconds: 2));

      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => HomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
    }
  }
}