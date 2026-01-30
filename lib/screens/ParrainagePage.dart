import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/controllers/RegisterBailleurCtrl.dart';
import 'package:casa/screens/termsAndPrivacy/TermsAndPrivacyPage.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/country_codes.dart'; // Added
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/requetes.dart';
import 'package:casa/controllers/TypeAccountController.dart'; // Added
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

class ParrainagePage extends StatefulWidget {
  @override
  _ParrainagePageState createState() => _ParrainagePageState();
}

class _ParrainagePageState extends State<ParrainagePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _contactController = TextEditingController(); // Unified
  // final _phoneController = removed
  // final _emailController = removed
  final _passwordController = TextEditingController();
  final _cityController = TextEditingController();
  final _parrainSearchController = TextEditingController();

  // Focus nodes pour la navigation au clavier
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _contactFocus = FocusNode(); // Unified
  // final _phoneFocus = removed
  // final _emailFocus = removed
  final _cityFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _parrainFocus = FocusNode();

  bool _isLoading = false;
  bool _showPassword = false;
  bool _isSearchingParrains = false;
  bool _acceptConditions = false;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  // Suivi de la force du mot de passe en temps réel
  int _passwordStrength = 0;

  // Variables pour le parrainage
  List<Map<String, dynamic>> _availableParrains = [];
  List<Map<String, dynamic>> _filteredParrains = [];
  Map<String, dynamic>? _selectedParrain;

  // Variables pour suivre l'interaction utilisateur avec chaque champ
  bool _firstNameTouched = false;
  bool _lastNameTouched = false;
  bool _contactTouched = false; // Unified
  // bool _phoneTouched = removed
  // bool _emailTouched = removed
  bool _cityTouched = false;
  bool _passwordTouched = false;

  // Unified contact field logic
  bool _isPhoneInput = false;
  String _selectedCountryCode = '+243'; 
  final Map<String, String> _countryFlags = Map<String, String>.from(countryFlags); // Needs import

  // Couleurs cohérentes avec le login - uniquement bleu
  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color lightBlue = Color(0xFFE3F2FD);
  final Color textColor = Color(0xFF1A237E);
  final Color secondaryTextColor = Color(0xFF5C6BC0);
  final Color errorColor = Color(0xFFD63031);
  final Color successColor = Color(0xFF38B000);

  String _selectedAccountType = 'Bailleur';
  // Dynamic Map from TypeAccountController can represent this, but for now we keep UI logic simple
  // We will load types dynamically.

  @override
  void initState() {
    super.initState();

    _passwordController.addListener(_updatePasswordStrength);
    _setupFocusNavigation();
    _loadInitialParrains();

    // Initialiser le controller de type
    WidgetsBinding.instance.addPostFrameCallback((_) async {
       await context.read<TypeAccountController>().fetchTypeAccounts();
    });

    _firstNameController.addListener(_updateButtonState);
    _lastNameController.addListener(_updateButtonState);
    _contactController.addListener(_updateContactType); // Unified
    _cityController.addListener(_updateButtonState);
    _passwordController.addListener(_updateButtonState);
    // _emailController removed

    _setupFieldTouchListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
        });
      }
    });
  }

  void _setupFieldTouchListeners() {
    _firstNameFocus.addListener(() {
      if (!_firstNameFocus.hasFocus && _firstNameController.text.isNotEmpty) {
        setState(() => _firstNameTouched = true);
      }
    });

    _lastNameFocus.addListener(() {
      if (!_lastNameFocus.hasFocus && _lastNameController.text.isNotEmpty) {
        setState(() => _lastNameTouched = true);
      }
    });

    _contactFocus.addListener(() {
      if (!_contactFocus.hasFocus && _contactController.text.isNotEmpty) {
        setState(() => _contactTouched = true);
      }
    });

    _cityFocus.addListener(() {
      if (!_cityFocus.hasFocus && _cityController.text.isNotEmpty) {
        setState(() => _cityTouched = true);
      }
    });

    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus && _passwordController.text.isNotEmpty) {
        setState(() => _passwordTouched = true);
      }
    });
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

  String? _getCountryNameFromCode(String code) {
    // Inverse lookup from countryCodes map if needed, or just return code for now
    // Since we don't have the full map here, we return null or basic logic
    return null; 
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
    _contactController.removeListener(_updateContactType);
    _cityController.removeListener(_updateButtonState);
    _passwordController.removeListener(_updateButtonState);
    
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _contactFocus.dispose();
    _cityFocus.dispose();
    _passwordFocus.dispose();
    _parrainFocus.dispose();
    super.dispose();
  }

  void _setupFocusNavigation() {
    // Navigation entre les champs
    _firstNameFocus.addListener(() {
      if (!_firstNameFocus.hasFocus) {
        if (_firstNameController.text.isNotEmpty && !_firstNameTouched) {
          setState(() => _firstNameTouched = true);
        }
      }
    });

    _lastNameFocus.addListener(() {
      if (!_lastNameFocus.hasFocus) {
        if (_lastNameController.text.isNotEmpty && !_lastNameTouched) {
          setState(() => _lastNameTouched = true);
        }
      }
    });

    _contactFocus.addListener(() {
      if (!_contactFocus.hasFocus) {
        if (_contactController.text.isNotEmpty && !_contactTouched) {
          setState(() => _contactTouched = true);
        }
      }
    });

    _cityFocus.addListener(() {
      if (!_cityFocus.hasFocus) {
        if (_cityController.text.isNotEmpty && !_cityTouched) {
          setState(() => _cityTouched = true);
        }
      }
    });

    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) {
        if (_passwordController.text.isNotEmpty && !_passwordTouched) {
          setState(() => _passwordTouched = true);
        }
      }
    });
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

  void _searchParrains(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearchingParrains = false;
        _filteredParrains = [];
      });
      return;
    }

    setState(() {
      _isSearchingParrains = true;
    });

    final filtered = _availableParrains.where((parrain) {
      return parrain['name'].toLowerCase().contains(query.toLowerCase()) ||
          parrain['phone'].contains(query) ||
          parrain['type'].toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      _filteredParrains = filtered;
    });
  }

  // Simulation du chargement des parrains
  void _loadInitialParrains() async {
    await Future.delayed(Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _availableParrains = [
          {
            'id': 1,
            'name': 'Jean Kabasele',
            'type': 'Locataire',
            'phone': '+243810000001'
          },
          {
            'id': 2,
            'name': 'Marie Lukusa',
            'type': 'Commissionnaire',
            'phone': '+243810000002'
          },
          {
            'id': 3,
            'name': 'Paul Mbayo',
            'type': 'Locataire',
            'phone': '+243810000003'
          },
          {
            'id': 4,
            'name': 'Sarah Ntumba',
            'type': 'Commissionnaire',
            'phone': '+243810000004'
          },
          {
            'id': 5,
            'name': 'David Mutombo',
            'type': 'Locataire',
            'phone': '+243810000005'
          },
        ];
      });
    }
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
                  primaryColor.withOpacity(0.06),
                  primaryColor.withOpacity(0.02),
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
        // Logo container avec badge de parrainage
        Stack(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primaryColor, darkBlue],
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
                  Icon(Icons.people_alt_rounded, size: 40, color: Colors.white),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Icon(Icons.people_alt_rounded, size: 40, color: Colors.white.withOpacity(0.3)),
                  ),
                ],
              ),
            ),
            // Badge parrainage
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: primaryColor, width: 2),
                ),
                child: Icon(Icons.star, size: 12, color: primaryColor),
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
                  'Parrainage',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Rejoignez Casa grâce à un parrain',
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

  Widget _buildParrainageBenefits() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: primaryColor, size: 18),
              SizedBox(width: 8),
              Text(
                'Avantages du Parrainage',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildBenefitItem('✓ Commission réduite sur votre première location'),
          _buildBenefitItem('✓ Accompagnement personnalisé par votre parrain'),
          _buildBenefitItem('✓ Le commissionnaire parrain reçoit un % sur tous vos nouveaux contrats'),
          _buildBenefitItem('✓ Support dédié pour vos premières locations'),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
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
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: color,
          width: 2,
        ),
        boxShadow: [
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
          onTap: null, // ← Rendre non cliquable
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    config['icon'] as IconData,
                    color: Colors.white,
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
                          color: color,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        config['description'] as String,
                        style: TextStyle(
                          color: color.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toujours afficher la coche puisque c'est sélectionné par défaut
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                  child: Icon(Icons.check_rounded, color: Colors.white, size: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParrainField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Votre Parrain',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),

        // Champ de recherche avec dropdown
        Container(
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
            controller: _parrainSearchController,
            focusNode: _parrainFocus,
            style: TextStyle(color: textColor, fontSize: 16),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              _searchParrains(value);
            },
            decoration: InputDecoration(
              labelText: 'Rechercher un parrain',
              labelStyle: TextStyle(color: secondaryTextColor),
              prefixIcon: Container(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.person_search_rounded, color: primaryColor),
              ),
              suffixIcon: _parrainSearchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: secondaryTextColor),
                onPressed: () {
                  setState(() {
                    _parrainSearchController.clear();
                    _selectedParrain = null;
                    _isSearchingParrains = false;
                    _filteredParrains = [];
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
              filled: true,
              fillColor: lightBlue.withOpacity(0.3),
              hintText: 'Tapez le nom ou téléphone du parrain...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ),

        // Dropdown des résultats de recherche
        if (_isSearchingParrains && _filteredParrains.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                physics: BouncingScrollPhysics(),
                itemCount: _filteredParrains.length,
                itemBuilder: (context, index) {
                  final parrain = _filteredParrains[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primaryColor.withOpacity(0.2),
                      child: Icon(
                        Icons.person_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      parrain['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      '${parrain['type']} • ${parrain['phone']}',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                    onTap: () {
                      setState(() {
                        _selectedParrain = parrain;
                        _parrainSearchController.text = parrain['name'];
                        _isSearchingParrains = false;
                        _filteredParrains = [];
                      });
                      _parrainFocus.unfocus();
                    },
                  );
                },
              ),
            ),
          ),

        // Affichage du parrain sélectionné
        if (_selectedParrain != null)
          Container(
            margin: EdgeInsets.only(top: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_rounded, color: primaryColor, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parrain sélectionné:',
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_selectedParrain!['name']} (${_selectedParrain!['type']})',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 16, color: primaryColor),
                  onPressed: () {
                    setState(() {
                      _selectedParrain = null;
                      _parrainSearchController.clear();
                    });
                  },
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
      ],
    ).animate().slideY(
      begin: 0.2,
      duration: 500.ms,
      delay: 1650.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildAccountTypeField() {
    // Utiliser le contrôleur pour récupérer les types dynamiquement
    final typeAccountCtrl = context.watch<TypeAccountController>();
    final ownerTypes = typeAccountCtrl.ownerTypes;
    
    // Filtrer pour ne garder que "Bailleur" si possible, sinon afficher tous les types propriétaires
    // Si la liste est vide (chargement), on affiche un indicateur ou rien
    if (ownerTypes.isEmpty) {
        return SizedBox.shrink(); 
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête avec badge "Recommandé"
        Row(
          children: [
            Text(
              'Type de compte*',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Text(
                "Obligatoire",
                style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),

        // Message informatif
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primaryColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: primaryColor, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Le parrainage est disponible uniquement pour les bailleurs',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),

        // Options de compte dynamiques
        ...ownerTypes.map((type) {
            // Mapping simple pour l'icône et la couleur si besoin, sinon par défaut
            return _buildAccountTypeOption(
                type['name'] ?? 'Bailleur', 
                {
                  'value': type['typeAccountId'],
                  'icon': Icons.house_siding_rounded,
                  'description': type['description'] ?? 'Compte propriétaire',
                  'color': Color(0xFF2196F3),
                }
            );
        }).toList(),
      ],
    ).animate().slideY(
      begin: 0.2,
      duration: 500.ms,
      delay: 1600.ms,
      curve: Curves.easeOut,
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
            nextFocus: _contactFocus, 
          ),
          SizedBox(height: 15),
          SizedBox(height: 15),
          // Contact Unifié
          _buildContactField(),
          SizedBox(height: 15),
          // Ville removed phone and email calls
          SizedBox(height: 15),
          // Ville
          _buildCityField(),
          SizedBox(height: 15),
          // Type de compte (fixé à Bailleur)
          _buildAccountTypeField(),
          SizedBox(height: 15),
          // Champ de parrain
          _buildParrainField(),
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
                    if (_autoValidateMode == AutovalidateMode.always && !_acceptConditions)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Veuillez accepter les conditions pour continuer',
                          style: TextStyle(
                            color: errorColor,
                            fontSize: 12,
                          ),
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
    ).animate().fadeIn(delay: 2200.ms);
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
          // Badge de parrainage
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, darkBlue],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'Programme de Parrainage',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 15),

          Text(
            'Inscription avec Parrain',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ).animate().fadeIn(delay: 1100.ms),

          SizedBox(height: 10),

          Text(
            'Créez votre compte Bailleur et bénéficiez des avantages du parrainage',
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 1200.ms),

          SizedBox(height: 20),

          // Avantages du parrainage
          _buildParrainageBenefits(),

          SizedBox(height: 25),

          _buildAuthForm(),
          SizedBox(height: 20),
          // Case à cocher pour les conditions
          _buildPrivacyText(),
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

  Widget _buildNameField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    bool isFirstField = false,
  }) {
    // Déterminer si ce champ doit afficher les erreurs
    bool shouldValidate = _autoValidateMode == AutovalidateMode.always ||
        (isFirstField ? _firstNameTouched : _lastNameTouched);

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
        autovalidateMode: shouldValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
        style: TextStyle(color: textColor, fontSize: 16),
        textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
        onFieldSubmitted: nextFocus != null ? (_) => _goToNextField(focusNode, nextFocus!) : null,
        onChanged: (value) {
          // Marquer comme touché seulement si l'utilisateur a vraiment tapé quelque chose
          if (value.isNotEmpty) {
            if (isFirstField && !_firstNameTouched) {
              setState(() => _firstNameTouched = true);
            } else if (!isFirstField && !_lastNameTouched) {
              setState(() => _lastNameTouched = true);
            }
          }
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
        ),
        validator: (value) => _validateName(value, label.toLowerCase()),
      ),
    ).animate().slideX(
      begin: -0.3,
      duration: 500.ms,
      delay: 1300.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildCountryCodePicker() {
    return Container(
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: PopupMenuButton<String>(
        onSelected: (value) {
          setState(() {
            _selectedCountryCode = value;
            _contactController.notifyListeners(); // Re-validate if needed
          });
        },
        itemBuilder: (BuildContext context) {
          return _countryFlags.keys.map((String code) {
            return PopupMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  Text(_countryFlags[code]!, style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(code, style: TextStyle(fontSize: 14)),
                ],
              ),
            );
          }).toList();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_countryFlags[_selectedCountryCode]!, style: TextStyle(fontSize: 18)),
              SizedBox(width: 4),
              Text(_selectedCountryCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
              Icon(Icons.arrow_drop_down, size: 18, color: textColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactField() {
    bool shouldValidate = _autoValidateMode == AutovalidateMode.always || _contactTouched;

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
        autovalidateMode: shouldValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
        style: TextStyle(color: textColor, fontSize: 16),
        keyboardType: _isPhoneInput ? TextInputType.phone : TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => _goToNextField(_contactFocus, _cityFocus),
        onChanged: (value) {
          if (value.isNotEmpty && !_contactTouched) {
            setState(() => _contactTouched = true);
          }
           // IMPORTANT: Trigger logic to detect if phone/email
           _updateContactType();
        },
        decoration: InputDecoration(
          labelText: 'Email ou Téléphone*',
          labelStyle: TextStyle(color: secondaryTextColor),
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(
               _isPhoneInput ? Icons.phone_iphone_rounded : Icons.email_rounded,
               color: primaryColor
            ),
          ),
          prefix: _isPhoneInput 
            ? Container(
                margin: EdgeInsets.only(right: 8),
                child: _buildCountryCodePicker(),
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
          hintText: _isPhoneInput ? '81 000 0000' : 'exemple@email.com',
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        validator: _validateContact,
      ),
    ).animate().slideX(
      begin: 0.3,
      duration: 500.ms,
      delay: 1400.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildCityField() {
    bool shouldValidate = _autoValidateMode == AutovalidateMode.always || _cityTouched;

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
        autovalidateMode: shouldValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
        style: TextStyle(color: textColor, fontSize: 16),
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => _goToNextField(_cityFocus, _parrainFocus),
        onChanged: (value) {
          if (value.isNotEmpty && !_cityTouched) {
            setState(() => _cityTouched = true);
          }
        },
        decoration: InputDecoration(
          labelText: 'Ville*',
          labelStyle: TextStyle(color: secondaryTextColor),
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.location_city_rounded, color: primaryColor),
          ),
          suffixIcon: _buildNextButton(() => _goToNextField(_cityFocus, _parrainFocus)),
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

  Widget _buildPasswordField() {
    bool shouldValidate = _autoValidateMode == AutovalidateMode.always || _passwordTouched;

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
        autovalidateMode: shouldValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _passwordFocus.unfocus(),
        onChanged: (value) {
          if (value.isNotEmpty && !_passwordTouched) {
            setState(() => _passwordTouched = true);
          }
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
    // Vérifier si tous les champs sont valides
    final isFormValid = _isFormValid();

    // Le bouton est activé seulement si le formulaire est valide ET les conditions sont acceptées
    final isButtonEnabled = isFormValid && _acceptConditions && !_isLoading;

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
            Icon(Icons.people_alt_rounded, size: 20, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Créer mon compte',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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

  // CORRECTION : Méthode améliorée pour vérifier la validité du formulaire
  bool _isFormValid() {
    // Vérifier d'abord que tous les champs requis sont remplis
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _contactController.text.isEmpty ||
        _cityController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      return false;
    }

    // Ensuite vérifier que chaque champ est valide en utilisant les validateurs
    if (_validateName(_firstNameController.text, 'prénom') != null) return false;
    if (_validateName(_lastNameController.text, 'nom') != null) return false;
    if (_validateContact(_contactController.text) != null) return false;
    if (_validateCity(_cityController.text) != null) return false;
    if (_validatePassword(_passwordController.text) != null) return false;

    return true;
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

  String? _validateContact(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ce champ est obligatoire';
    }

    // Check locally if looks like phone
    final isPhone = _looksLikePhoneNumber(value);

    if (isPhone) {
        final cleanedValue = value.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
        // Validation spécifique selon le pays sélectionné
        if (_selectedCountryCode == '+243') {
           if (cleanedValue.length != 9) return 'Le numéro RDC doit avoir 9 chiffres';
           if (!RegExp(r'^[89]').hasMatch(cleanedValue)) return 'Le numéro RDC doit commencer par 8 ou 9';
        } else {
           if (cleanedValue.length < 8) return 'Numéro de téléphone trop court';
        }
    } else {
        // Validation email
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(value)) return 'Email invalide';
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


  String? _validateCity(String? value) {
    if (value == null || value.isEmpty) {
      return 'La ville est obligatoire';
    }
    if (value.length < 2) {
      return 'La ville doit contenir au moins 2 caractères';
    }
    return null;
  }

  void _forceRevalidation() {
    if (_formKey.currentState != null) {
      _formKey.currentState!.validate();
    }
  }

  Future<void> _handleRegister() async {
    // Activer la validation pour tous les champs
    setState(() {
      _autoValidateMode = AutovalidateMode.always;
      // Marquer tous les champs comme touchés pour forcer l'affichage des erreurs
      _firstNameTouched = true;
      _lastNameTouched = true;
      _contactTouched = true;
      _cityTouched = true;
      _passwordTouched = true;
    });

    await Future.delayed(Duration(milliseconds: 50));

    // Vérifier la validation avec la méthode standard du formulaire
    if (!(_formKey.currentState?.validate() ?? false)) {
      FancyNotification.show(context, "Veuillez corriger les erreurs ci-dessus");
      return;
    }
    if (!_acceptConditions) {
      FancyNotification.show(context, "Veuillez accepter les conditions d'utilisation");
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
      // Recalculer si c'est un téléphone ou email pour la soumission
      String phoneField = '';
      String emailField = '';
      
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

      // Récupérer l'ID du type de compte Bailleur dynamiquement
      int accountTypeId = 3; // Fallback
      final typeAccountCtrl = context.read<TypeAccountController>();
      if (typeAccountCtrl.ownerTypes.isNotEmpty) {
           final validTypes = typeAccountCtrl.ownerTypes.where(
              (t) => (t['name'] ?? '').toString().toLowerCase().contains('bailleur')
           ).toList();
           if (validTypes.isNotEmpty) {
               accountTypeId = validTypes.first['typeAccountId'] ?? 3;
           } else {
               // Si pas de "Bailleur" explicite, prendre le premier type propriétaire (ex: Propriétaire)
               accountTypeId = typeAccountCtrl.ownerTypes.first['typeAccountId'] ?? 3;
           }
      }

      final Map<String, dynamic> userData = {
        "password": _passwordController.text,
        "city": _cityController.text.trim(),
        "country": "RDC",
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
          "parrainId": _selectedParrain != null ? _selectedParrain!['id'] : 0,
          "numberCard": ""
      };
      
      // Payload unifié standard
      final Map<String, dynamic> payload = {
        "user": userData,
        "account": [{"typeAccount": accountTypeId}],
        "actor": actorData
      };

      final authCtrl = context.read<AuthentificationCtrl>();
      final response = await authCtrl.register(payload, url: '');

      if (!mounted) return;

      if (response.status == true) {
        String successMessage = "Inscription réussie!";
        if (_selectedParrain != null) {
          successMessage += " Votre parrain ${_selectedParrain!['name']} a été notifié.";
        }

        FancyNotification.show(context, successMessage, isError: false);
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Routes.loginRoute,
                (route) => false,
          );
        }
      } else {
        String errorMsg = _sanitizeError(response.errorMsg);
        FancyNotification.show(context, errorMsg);
      }
    } catch (e) {
      FancyNotification.show(context, "Une erreur est survenue. Veuillez réessayer.");
      print("Register error: $e");
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