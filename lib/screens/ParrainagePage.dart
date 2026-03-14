import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/controllers/RegisterBailleurCtrl.dart';
import 'package:casa/screens/termsAndPrivacy/TermsAndPrivacyPage.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/country_codes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/city_suggestions.dart';
import 'package:casa/utils/requetes.dart';
import 'package:casa/controllers/TypeAccountController.dart';
import 'package:casa/models/CityModel.dart';
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
  bool _contactTouched = false;
  bool _cityTouched = false;
  bool _passwordTouched = false;

  // Sélection du type de compte (identique à RegisterScreen)
  bool _isLocataireSelected = false;
  int? _selectedOwnerAccountId;
  int? _selectedPrestataireAccountId;

  // Unified contact field logic
  bool _isPhoneInput = false;
  String _selectedCountryCode = '+243'; 
  final Map<String, String> _countryFlags = Map<String, String>.from(countryFlags); // Needs import

  // Couleurs cohérentes avec le login
  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color lightBlue = Color(0xFFE3F2FD);
  final Color textColor = Color(0xFF1A237E);
  final Color secondaryTextColor = Color(0xFF5C6BC0);
  final Color errorColor = Color(0xFFD63031);
  final Color successColor = Color(0xFF38B000);

  // Liste de villes pour l'autocomplete (identique à RegisterScreen)
  static final List<String> _allCities = List<String>.from(citySuggestions);
  String? _selectedCountryName;

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
      if (!_cityFocus.hasFocus) {
         // Pour l'autocomplete, on attend un peu
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
    final strength = password.length;

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
          // Arrière-plan identique au login/register
          _buildBackground(),

          // Contenu principal
          SafeArea(
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 24),
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
          SizedBox(height: 12),
          _buildBenefitItem('✓ Participation automatique à notre Grand Jeu Tombola'),
          _buildBenefitItem('✓ Chance de gagner des prix incroyables (Smartphones, Bons d\'achat, etc.)'),
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
            onTapOutside: (event) {
              _parrainFocus.unfocus();
            },
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
    ).animate().slideY(
      begin: 0.2,
      duration: 500.ms,
      delay: 1600.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildCategoryHeader({
    required String title,
    required IconData icon,
    required bool isSelected,
    bool showBadge = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? primaryColor : Colors.grey.shade600, size: 24),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? primaryColor : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
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
      margin: EdgeInsets.only(top: 8, left: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((type) {
          final id = type['id'] as int;
          final name = type['name'] as String;
          final isItemSelected = selectedId == id;
          
          return InkWell(
            onTap: () => onSelected(id),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isItemSelected ? primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isItemSelected ? primaryColor : Colors.grey.shade300),
              ),
              child: Text(
                name,
                style: TextStyle(
                  color: isItemSelected ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: isItemSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1);
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
            isTouched: _firstNameTouched,
            onChanged: (val) {
               if (!_firstNameTouched && val.isNotEmpty) setState(() => _firstNameTouched = true);
            },
          ),
          SizedBox(height: 15),
          _buildNameField(
            controller: _lastNameController,
            label: 'Nom',
            hint: 'Baka',
            focusNode: _lastNameFocus,
            nextFocus: _contactFocus,
            isTouched: _lastNameTouched,
            onChanged: (val) {
               if (!_lastNameTouched && val.isNotEmpty) setState(() => _lastNameTouched = true);
            },
          ),
          SizedBox(height: 15),
          // Contact Unifié
          _buildContactField(),
          SizedBox(height: 15),
          // Ville
          _buildCityField(),
          SizedBox(height: 15),
          // Type de compte
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
                                'Vous devez accepter les conditions pour continuer',
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
      ],
    ).animate().fadeIn(delay: 2200.ms);
  }

  Widget _buildAuthCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10), // Reduced radius to match RegisterScreen
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
            'Inscription avec Parrain',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ).animate().fadeIn(delay: 1100.ms),

          SizedBox(height: 10),

          Text(
            'Créez votre compte et bénéficiez des avantages du parrainage',
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

  Widget _buildNameField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required bool isTouched,
    required Function(String) onChanged,
  }) {
    // Déterminer si ce champ doit afficher les erreurs
    bool shouldValidate = _autoValidateMode == AutovalidateMode.always || isTouched;

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
        onFieldSubmitted: nextFocus != null ? (_) => _goToNextField(focusNode, nextFocus) : null,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: secondaryTextColor),
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.person_rounded, color: primaryColor),
          ),
          suffixIcon: nextFocus != null ? _buildNextButton(() => _goToNextField(focusNode, nextFocus)) : null,
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
          errorText: shouldValidate ? _validateName(controller.text, label.toLowerCase()) : null,
        ),
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
      width: 140, // Légèrement plus large pour accommoder le nom
      padding: EdgeInsets.only(left: 8, right: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCountryCode,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down_rounded, color: primaryColor, size: 20),
          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
          items: _countryFlags.entries.map((entry) {
            String countryName = entry.key == '+243' ? 'RDC' : ''; // simplified or use a map
            return DropdownMenuItem(
              value: entry.key,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.value, style: TextStyle(fontSize: 16)), // Drapeau
                  SizedBox(width: 8),
                  Text(entry.key, style: TextStyle(fontSize: 13)), // Indicatif
                  if (countryName.isNotEmpty) ...[
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        countryName,
                        style: TextStyle(fontSize: 12, color: secondaryTextColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
          if (!_contactTouched && value.isNotEmpty) {
            setState(() => _contactTouched = true);
          }
          _updateContactType();
          _forceRevalidation();
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
          }).take(10);
        },
        displayStringForOption: (CityModel city) => city.name ?? '',
        onSelected: (CityModel city) {
          setState(() {
            _cityController.text = city.name ?? '';
            _cityTouched = true;
            FocusScope.of(context).requestFocus(_parrainFocus);
          });
        },
        fieldViewBuilder: (
          BuildContext context,
          TextEditingController textEditingController,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted,
        ) {
          // Synchroniser avec _cityController
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (textEditingController.text != _cityController.text && mounted) {
              textEditingController.text = _cityController.text;
            }
          });
          
          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: Colors.black87, fontSize: 16),
            onTapOutside: (event) {
              focusNode.unfocus();
            },
            onFieldSubmitted: (String value) {
              onFieldSubmitted();
              _goToNextField(focusNode, _parrainFocus);
            },
            onChanged: (String value) {
              setState(() {
                _cityController.text = value;
                _cityTouched = true;
              });
              _forceRevalidation();
            },
            decoration: InputDecoration(
              labelText: 'Ville*',
              labelStyle: TextStyle(color: Colors.black87),
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
          );
        },
        optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<CityModel> onSelected, Iterable<CityModel> options) {
          if (options.isEmpty) return SizedBox.shrink();

          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8.0,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: BoxConstraints(maxHeight: 250),
                width: MediaQuery.of(context).size.width - 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (BuildContext context, int index) {
                    final CityModel city = options.elementAt(index);
                    return ListTile(
                      leading: Icon(Icons.location_city_rounded, color: primaryColor, size: 20),
                      title: Text(city.name ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      onTap: () => onSelected(city),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    ).animate().slideX(
      begin: 0.3, duration: 500.ms, delay: 1550.ms, curve: Curves.easeOut,
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
        style: TextStyle(color: Colors.black87, fontSize: 16),
        obscureText: !_showPassword,
        autovalidateMode: AutovalidateMode.disabled,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _passwordFocus.unfocus(),
        onChanged: (val) {
          if (!_passwordTouched && val.isNotEmpty) {
            setState(() => _passwordTouched = true);
          }
          _forceRevalidation();
        },
        onEditingComplete: () {
          setState(() => _passwordTouched = true);
        },
        decoration: InputDecoration(
          labelText: 'Mot de passe*',
          labelStyle: TextStyle(color: Colors.black87),
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
          errorText: _passwordTouched ? _validatePassword(_passwordController.text) : null,
        ),
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
      {'text': 'Au moins 6 caractères', 'met': password.length >= 6},
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
    if (strength == 0) return 'Entrez votre mot de passe';
    if (strength < 6) return 'Mot de passe trop court (min. 6)';
    return 'Mot de passe valide';
  }

  Color _getPasswordStrengthColor(int strength) {
    if (strength == 0) return secondaryTextColor;
    if (strength < 3) return errorColor;
    if (strength < 6) return Colors.orange;
    return successColor;
  }

  Widget _buildAuthButton() {
    final hasRequiredFields = _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty &&
        _contactController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty;

    final isFormValid = _isFormValid();
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

  bool _isFormValid() {
    final isFirstNameValid = _firstNameController.text.isEmpty || _validateName(_firstNameController.text, 'prénom') == null;
    final isLastNameValid = _lastNameController.text.isEmpty || _validateName(_lastNameController.text, 'nom') == null;
    final isContactValid = _contactController.text.isEmpty || _validateContact(_contactController.text) == null;
    final isCityValid = _cityController.text.isEmpty || _validateCity(_cityController.text) == null;
    final isPasswordValid = _passwordController.text.isEmpty || _validatePassword(_passwordController.text) == null;

    return isFirstNameValid &&
        isLastNameValid &&
        isContactValid &&
        isCityValid &&
        isPasswordValid;
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
      _firstNameTouched = true;
      _lastNameTouched = true;
      _contactTouched = true;
      _cityTouched = true;
      _passwordTouched = true;
    });

    await Future.delayed(Duration(milliseconds: 50));

    // Vérifier la validation
    final isNameFieldsValid = _validateName(_firstNameController.text, 'prénom') == null &&
        _validateName(_lastNameController.text, 'nom') == null;
    final isContactValid = _validateContact(_contactController.text) == null;
    final isCityValid = _validateCity(_cityController.text) == null;
    final isPasswordValid = _validatePassword(_passwordController.text) == null;

    if (!isNameFieldsValid || !isContactValid || !isCityValid || !isPasswordValid) {
      FancyNotification.show(context, "Veuillez corriger les erreurs ci-dessus");
      return;
    }

    if (!_isLocataireSelected && _selectedOwnerAccountId == null && _selectedPrestataireAccountId == null) {
      FancyNotification.show(context, "Veuillez sélectionner au moins un type de compte");
      return;
    }

    if (!_acceptConditions) {
      FancyNotification.show(context, "Veuillez accepter les conditions d'utilisation");
      return;
    }

    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);

    FocusScope.of(context).unfocus();

    if (!await NetworkUtils.checkInternetConnectivity()) {
      FancyNotification.show(context, "Pas de connexion internet");
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Trouver les IDs des comptes sélectionnés
      List<Map<String, int>> accountsPayload = [];
      if (_isLocataireSelected) {
        accountsPayload.add({"typeAccount": 4}); // Locataire (ID standard)
      }
      if (_selectedOwnerAccountId != null) {
        accountsPayload.add({"typeAccount": _selectedOwnerAccountId!}); 
      }
      if (_selectedPrestataireAccountId != null) {
        accountsPayload.add({"typeAccount": _selectedPrestataireAccountId!});
      }

      // Préparer les données de contact
      String phoneField = '';
      String emailField = '';
      
      final contactValue = _contactController.text.trim();
      final isPhone = _looksLikePhoneNumber(contactValue);

      if (isPhone) {
        final cleanedPhone = contactValue.replaceAll(RegExp(r'[^\d]'), '');
        phoneField = cleanedPhone.startsWith('0') 
            ? '${_selectedCountryCode}${cleanedPhone.substring(1)}'
            : '${_selectedCountryCode}$cleanedPhone';
        if (phoneField == _selectedCountryCode) phoneField = contactValue;
      } else {
        emailField = contactValue;
      }

      final Map<String, dynamic> userData = {
        "password": _passwordController.text,
        "city": _cityController.text.trim(),
        "country": _selectedCountryName ?? "RDC",
        "username": "${_firstNameController.text.trim()}${_lastNameController.text.trim()}".replaceAll(' ', '').toLowerCase(),
        "phone": isPhone ? phoneField : "",
        "email": isPhone ? "" : emailField,
      };
      
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
      
      final Map<String, dynamic> payload = {
        "user": userData,
        "account": accountsPayload,
        "actor": actorData
      };

      final authCtrl = context.read<AuthentificationCtrl>();
      final response = await authCtrl.register(payload, url: '');

      if (!mounted) return;

      if (response.status == true) {
        String successMessage = "Inscription réussie ! Bravo pour votre participation à notre Tombola !";
        if (_selectedParrain != null) {
          successMessage += " Votre parrain ${_selectedParrain!['name']} a été notifié.";
        }
        FancyNotification.show(context, successMessage, isError: false);
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, Routes.loginRoute, (route) => false);
      } else {
        FancyNotification.show(context, _sanitizeError(response.errorMsg));
      }
    } catch (e) {
      FancyNotification.show(context, "Une erreur est survenue. Veuillez réessayer.");
      print("Register error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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