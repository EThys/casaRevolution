import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/controllers/RegisterBailleurCtrl.dart';
import 'package:casa/screens/termsAndPrivacy/TermsAndPrivacyPage.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/country_codes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/city_suggestions.dart';
import 'package:casa/utils/requetes.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/controllers/TypeAccountController.dart';
import 'package:casa/models/CityModel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ParrainagePage extends StatefulWidget {
  @override
  _ParrainagePageState createState() => _ParrainagePageState();
}

class _ParrainagePageState extends State<ParrainagePage> {
  final _formKey = GlobalKey<FormState>();
  final _formKeyAccount = GlobalKey<FormState>();
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
  bool _loadingParrainUsers = false;
  bool _acceptConditions = false;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  /// 0 = programme, 1 = profil, 2 = type de compte, 3 = parrain + mot de passe + CGU.
  int _parrainageStep = 0;

  // Suivi de la force du mot de passe en temps réel
  int _passwordStrength = 0;

  // Variables pour le parrainage
  List<Map<String, dynamic>> _availableParrains = [];
  List<Map<String, dynamic>> _filteredParrains = [];
  bool _isSearchingParrains = false;
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

  /// Palette « feed » (Twitter / produit SV) tout en gardant le bleu CasaNayo.
  static const Color _twTextPrimary = Color(0xFF0F1419);
  static const Color _twTextSecondary = Color(0xFF536471);
  static const Color _twBorder = Color(0xFFEFF3F4);
  static const Color _pageBg = Color(0xFFF7F9F9);

  static const List<String> _stepTitles = [
    'Programme',
    'Profil',
    'Type de compte',
    'Parrain & accès',
  ];

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
    _parrainSearchController.dispose();

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

  int _userIdFromParrainMap(Map<String, dynamic> parrain) {
    final v = parrain['userId'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// Libellé public pour la liste / la puce (aucun identifiant métier affiché).
  String _parrainPublicSubtitle(Map<String, dynamic> parrain) {
    for (final key in ['city', 'ville', 'commune']) {
      final s = parrain[key]?.toString().trim() ?? '';
      if (s.isNotEmpty && s != 'null') return s;
    }
    return 'Membre CasaNayo';
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

    final q = query.toLowerCase().trim();
    final filtered = _availableParrains
        .where((parrain) {
          final name = (parrain['name'] as String? ?? '').toLowerCase();
          return name.contains(q);
        })
        .take(80)
        .toList();

    setState(() {
      _filteredParrains = filtered;
    });
  }

  /// Parrain choisi dans la liste, ou saisi au clavier si une seule correspondance exacte sur le nom.
  Map<String, dynamic>? _resolvedParrainForSubmit() {
    if (_selectedParrain != null) return _selectedParrain;
    final q = _parrainSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return null;
    final matches = _availableParrains.where((p) {
      final name = (p['name'] as String? ?? '').trim().toLowerCase();
      return name == q;
    }).toList();
    if (matches.length == 1) return matches.first;
    return null;
  }

  Future<void> _openParrainPicker() async {
    FocusScope.of(context).unfocus();
    if (_loadingParrainUsers) {
      FancyNotification.show(
        context,
        'La liste des parrains est en cours de chargement…',
        type: NotificationType.info,
      );
      return;
    }
    if (_availableParrains.isEmpty) {
      FancyNotification.show(
        context,
        'Aucun parrain disponible pour le moment. Réessayez plus tard.',
        type: NotificationType.warning,
      );
      return;
    }

    final filterCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered =
        List<Map<String, dynamic>>.from(_availableParrains);

    final picked = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final maxH = MediaQuery.of(ctx).size.height * 0.78;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                return Container(
                  constraints: BoxConstraints(maxHeight: maxH),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Choisir un parrain',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: Icon(Icons.close_rounded,
                                  color: secondaryTextColor),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TextField(
                          controller: filterCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Filtrer par nom…',
                            prefixIcon:
                                Icon(Icons.search_rounded, color: primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: primaryColor, width: 1.5),
                            ),
                          ),
                          onChanged: (v) {
                            final qq = v.toLowerCase().trim();
                            setModalState(() {
                              filtered = qq.isEmpty
                                  ? List<Map<String, dynamic>>.from(
                                      _availableParrains)
                                  : _availableParrains
                                      .where((p) => (p['name'] as String? ?? '')
                                          .toLowerCase()
                                          .contains(qq))
                                      .take(150)
                                      .toList();
                            });
                          },
                        ),
                      ),
                      Flexible(
                        child: filtered.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Aucun nom ne correspond à votre recherche.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: secondaryTextColor),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding:
                                    const EdgeInsets.fromLTRB(8, 0, 8, 16),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: Colors.grey.shade100),
                                itemBuilder: (c, i) {
                                  final parrain = filtered[i];
                                  final name =
                                      parrain['name'] as String? ?? '';
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          primaryColor.withOpacity(0.15),
                                      child: Icon(Icons.person_rounded,
                                          color: primaryColor, size: 22),
                                    ),
                                    title: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _parrainPublicSubtitle(parrain),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                    trailing: Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.grey.shade400),
                                    onTap: () => Navigator.pop(ctx, parrain),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    filterCtrl.dispose();

    if (picked != null && mounted) {
      setState(() {
        _selectedParrain = picked;
        _parrainSearchController.text = picked['name'] as String? ?? '';
      });
    }
  }

  Future<void> _loadInitialParrains() async {
    if (!mounted) return;
    setState(() => _loadingParrainUsers = true);
    try {
      final response = await getData(Endpoints.publicUsers, token: '');
      if (!mounted) return;
      final list = <Map<String, dynamic>>[];
      if (response is Map && response['users'] is List) {
        for (final e in response['users'] as List) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final rawId = m['userId'];
          final uid = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
          final name = m['name']?.toString().trim() ?? '';
          if (uid != null && uid > 0 && name.isNotEmpty) {
            final row = <String, dynamic>{'userId': uid, 'name': name};
            for (final key in ['city', 'ville', 'commune']) {
              final loc = m[key]?.toString().trim();
              if (loc != null && loc.isNotEmpty && loc != 'null') {
                row['city'] = loc;
                break;
              }
            }
            list.add(row);
          }
        }
        list.sort((a, b) => (a['name'] as String)
            .toLowerCase()
            .compareTo((b['name'] as String).toLowerCase()));
      }
      setState(() {
        _availableParrains = list;
        _loadingParrainUsers = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _availableParrains = [];
          _loadingParrainUsers = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        alignment: Alignment.center,
        children: [
          _buildBackground(),
          AbsorbPointer(
            absorbing: _isLoading,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                    const SizedBox(height: 10),
                    _buildLogo(),
                    const SizedBox(height: 30),
                    _buildAuthCard(),
                    const SizedBox(height: 10),
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
              padding: const EdgeInsets.all(16),
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
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage('assets/images/icon.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ).animate().scale(
              delay: 500.ms,
              duration: 800.ms,
              curve: Curves.elasticOut,
            ),
        const SizedBox(width: 8),
        Container(
          height: 40,
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: Colors.grey.withOpacity(0.3),
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
                child: const Text(
                  'CasaNayo',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _parrainageStep == 0
                    ? 'Programme parrainage'
                    : _parrainageStep == 1
                        ? 'Votre profil'
                        : _parrainageStep == 2
                            ? 'Type de compte'
                            : 'Parrain & accès',
                style: GoogleFonts.inter(
                  textStyle: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
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
    Widget line(String prefix, String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Text(
                prefix,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: _twTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _twBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pourquoi parrainer sur CasaNayo ?',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _twTextPrimary,
              letterSpacing: -0.25,
            ),
          ),
          const SizedBox(height: 16),
          line(
            '1.',
            'Invitez des proches à créer leur compte depuis l’application : à partir de 5 personnes parrainées et inscrites, vous devenez éligible au tirage au sort du concours CasaNayo.',
          ),
          line(
            '2.',
            'Si, parmi vos filleuls, certains souscrivent à un abonnement annuel, vos chances au tirage augmentent.',
          ),
          line(
            '3.',
            'Les gagnants peuvent participer à un concours pour remporter des bons d’achat, des forfaits internet, des véhicules et bien plus encore.',
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: _twBorder),
          const SizedBox(height: 12),
          Text(
            'Créez ensuite votre compte avec le nom de votre parrain pour rejoindre le programme.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: _twTextSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms);
  }

  Widget _buildStepProgressBar() {
    final stepIndex = _parrainageStep.clamp(0, 3);
    final progress = (stepIndex + 1) / 4.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Étape ${stepIndex + 1} sur 4',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor,
                letterSpacing: 0.15,
              ),
            ),
            Text(
              _stepTitles[stepIndex],
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _twTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: Colors.grey.shade200,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildParrainField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              if (_selectedParrain != null) {
                final selName =
                    (_selectedParrain!['name'] as String?)?.trim() ?? '';
                if (value.trim() != selName) {
                  setState(() => _selectedParrain = null);
                }
              }
              _searchParrains(value);
            },
            decoration: InputDecoration(
              labelText: 'Rechercher un parrain',
              labelStyle: TextStyle(color: secondaryTextColor),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              hintText: _loadingParrainUsers
                  ? 'Chargement des parrains…'
                  : 'Tapez le nom du parrain…',
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    title: Text(
                      parrain['name'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      _parrainPublicSubtitle(parrain),
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parrain sélectionné',
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        (_selectedParrain!['name'] as String?) ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        _parrainPublicSubtitle(_selectedParrain!),
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
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
        // SECTION 1: LOCATAIRE (CLIENT)
        _buildCategoryHeader(
          title: "Vous êtes Locataire ?",
          icon: null,
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
          icon: null,
          isSelected: _selectedOwnerAccountId != null,
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
          icon: null,
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
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: errorColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '!',
                    style: TextStyle(
                      color: errorColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
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
    IconData? icon,
    required bool isSelected,
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
            if (icon != null) ...[
              Icon(icon, color: isSelected ? primaryColor : Colors.grey.shade600, size: 24),
              SizedBox(width: 16),
            ] else ...[
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 14),
            ],
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
            Text(
              isSelected ? 'Oui' : ' ',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? primaryColor : Colors.transparent,
              ),
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
    );
  }

  bool _validateStep1Fields() {
    return _validateName(_firstNameController.text, 'prénom') == null &&
        _validateName(_lastNameController.text, 'nom') == null &&
        _validateContact(_contactController.text) == null &&
        _validateCity(_cityController.text) == null;
  }

  void _goToStep2From1() {
    setState(() {
      _autoValidateMode = AutovalidateMode.always;
      _firstNameTouched = true;
      _lastNameTouched = true;
      _contactTouched = true;
      _cityTouched = true;
    });
    if (!_validateStep1Fields()) {
      FancyNotification.show(
        context,
        'Complétez ou corrigez votre profil avant de continuer.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _parrainageStep = 2);
  }

  void _goToStep3From2() {
    if (!_isLocataireSelected &&
        _selectedOwnerAccountId == null &&
        _selectedPrestataireAccountId == null) {
      setState(() => _autoValidateMode = AutovalidateMode.always);
      FancyNotification.show(
        context,
        'Sélectionnez au moins un type de compte pour continuer.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _parrainageStep = 3);
  }

  Widget _sectionHeaderSv(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _twTextPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 1.35,
            color: _twTextSecondary,
          ),
        ),
      ],
    );
  }

  /// Champs étape 2 — profil (le parent [Form] fournit la clé).
  Widget _buildStep1FormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNameField(
          controller: _firstNameController,
          label: 'Prénom',
          hint: 'Jean',
          focusNode: _firstNameFocus,
          nextFocus: _lastNameFocus,
          isTouched: _firstNameTouched,
          onChanged: (val) {
            if (!_firstNameTouched && val.isNotEmpty) {
              setState(() => _firstNameTouched = true);
            }
          },
        ),
        const SizedBox(height: 14),
        _buildNameField(
          controller: _lastNameController,
          label: 'Nom',
          hint: 'Baka',
          focusNode: _lastNameFocus,
          nextFocus: _contactFocus,
          isTouched: _lastNameTouched,
          onChanged: (val) {
            if (!_lastNameTouched && val.isNotEmpty) {
              setState(() => _lastNameTouched = true);
            }
          },
        ),
        const SizedBox(height: 14),
        _buildContactField(),
        const SizedBox(height: 14),
        _buildCityField(),
      ],
    );
  }

  /// Étape 4 — parrain, mot de passe, indicateur de force.
  Widget _buildStep3FormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeaderSv(
          'Votre parrain',
          'Nom exact tel qu’affiché sur l’application.',
        ),
        const SizedBox(height: 8),
        _buildParrainField(),
        const SizedBox(height: 18),
        _sectionHeaderSv(
          'Mot de passe',
          'Au moins 6 caractères pour sécuriser votre compte.',
        ),
        const SizedBox(height: 8),
        _buildPasswordField(),
        const SizedBox(height: 8),
        _buildPasswordStrengthIndicator(),
      ],
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
                            Container(
                              width: 18,
                              height: 18,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: errorColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '!',
                                style: TextStyle(
                                  color: errorColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
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
    );
  }

  Widget _buildAuthCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: _twBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepProgressBar(),
          const SizedBox(height: 20),
          if (_parrainageStep == 0) ...[
            Text(
              'Parrainer, c’est\ngrandir ensemble',
              textAlign: TextAlign.left,
              style: GoogleFonts.inter(
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: _twTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Les règles du programme en un clin d’œil, puis quatre étapes pour finaliser votre inscription.',
              textAlign: TextAlign.left,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: _twTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _buildParrainageBenefits(),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => setState(() => _parrainageStep = 1),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  'Commencer',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Retour',
                  style: GoogleFonts.inter(
                    color: _twTextSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ] else if (_parrainageStep == 1) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _twTextPrimary),
                onPressed: () => setState(() => _parrainageStep = 0),
              ),
            ),
            Text(
              'Vos informations',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: _twTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pour vous joindre et personnaliser votre expérience CasaNayo.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                color: _twTextSecondary,
              ),
            ),
            const SizedBox(height: 22),
            AbsorbPointer(
              absorbing: _isLoading,
              child: Form(
                key: _formKey,
                autovalidateMode: _autoValidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStep1FormFields(),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _parrainageStep = 0),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _twTextPrimary,
                              side: const BorderSide(color: _twBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              'Retour',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _goToStep2From1,
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              'Continuer',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_parrainageStep == 2) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _twTextPrimary),
                onPressed: () => setState(() => _parrainageStep = 1),
              ),
            ),
            Text(
              'Type de compte',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: _twTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Indiquez comment vous utilisez CasaNayo (vous pourrez ajuster plus tard selon les règles du service).',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                color: _twTextSecondary,
              ),
            ),
            const SizedBox(height: 22),
            AbsorbPointer(
              absorbing: _isLoading,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAccountTypeField(),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _parrainageStep = 1),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _twTextPrimary,
                            side: const BorderSide(color: _twBorder),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Text(
                            'Retour',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _goToStep3From2,
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Text(
                            'Continuer',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _twTextPrimary),
                onPressed: () => setState(() => _parrainageStep = 2),
              ),
            ),
            Text(
              'Parrain et accès',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: _twTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Dernière étape : parrain, mot de passe et acceptation des conditions.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                color: _twTextSecondary,
              ),
            ),
            const SizedBox(height: 22),
            AbsorbPointer(
              absorbing: _isLoading,
              child: Form(
                key: _formKeyAccount,
                autovalidateMode: _autoValidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStep3FormFields(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildPrivacyText(),
            const SizedBox(height: 22),
            _buildAuthButton(),
            const SizedBox(height: 16),
            _buildLoginLink(),
          ],
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: _isPhoneInput && _contactController.text.isNotEmpty
              ? _buildCountryCodeDropdown()
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
          hintText: 'exemple@email.com ou 810000000',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          errorText: _contactTouched ? _validateContact(_contactController.text) : null,
        ),
        keyboardType: _isPhoneInput ? TextInputType.phone : TextInputType.emailAddress,
        onChanged: (String value) {
          if (!_contactTouched && value.isNotEmpty) {
            setState(() => _contactTouched = true);
          }
          final isPhone = _looksLikePhoneNumber(value);
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
          });
          FocusScope.of(context).unfocus();
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
              FocusScope.of(context).unfocus();
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          Text(
            isMet ? '✓' : '·',
            style: TextStyle(
              fontSize: 11,
              color: isMet ? successColor : Colors.grey.shade500,
              fontWeight: FontWeight.w700,
            ),
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
            : Text(
                'Créer mon compte',
                style: TextStyle(
                  fontSize: 16,
                  color: isButtonEnabled ? Colors.white : Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
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
    );
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
    _formKey.currentState?.validate();
    _formKeyAccount.currentState?.validate();
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
      FancyNotification.show(
        context,
        "Complétez ou corrigez les champs indiqués avant de continuer.",
      );
      return;
    }

    if (!_isLocataireSelected && _selectedOwnerAccountId == null && _selectedPrestataireAccountId == null) {
      FancyNotification.show(
        context,
        "Choisissez au moins un type de compte pour finaliser l’inscription.",
      );
      return;
    }

    if (!_acceptConditions) {
      FancyNotification.show(
        context,
        "Merci d’accepter les conditions d’utilisation pour poursuivre.",
      );
      return;
    }

    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);

    FocusScope.of(context).unfocus();

    if (!await NetworkUtils.checkInternetConnectivity()) {
      FancyNotification.show(
        context,
        "Connexion internet indisponible. Réessayez lorsque le réseau est stable.",
      );
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
      
      final resolvedParrain = _resolvedParrainForSubmit();
      final parrainUserId =
          resolvedParrain != null ? _userIdFromParrainMap(resolvedParrain) : 0;

      final actorData = {
          "lastName": _lastNameController.text.trim(),
          "firstName": _firstNameController.text.trim(),
          "address": _cityController.text.trim(),
          "images": "",
          "cardFront": "",
          "cardBack": "",
          "typeCardId": 0,
          "parrainId": parrainUserId,
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
        if (resolvedParrain != null) {
          successMessage +=
              " Votre parrain ${resolvedParrain['name']} a été notifié.";
        }
        FancyNotification.show(
          context,
          successMessage,
          isError: false,
          type: NotificationType.success,
        );
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, Routes.loginRoute, (route) => false);
      } else {
        FancyNotification.show(context, _sanitizeError(response.errorMsg));
      }
    } catch (e) {
      FancyNotification.show(
        context,
        "L’inscription n’a pas abouti. Vérifiez les informations et réessayez.",
      );
      print("Register error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  String _sanitizeError(String? error) {
    if (error == null || error.isEmpty) {
      return "L’inscription n’a pas pu être finalisée. Réessayez dans quelques instants.";
    }
    final lower = error.toLowerCase();

    if (lower.contains("internal server error") ||
        lower.contains("exception") ||
        lower.contains("status") ||
        lower.contains("timeout") ||
        lower.contains("connection refused") ||
        error.startsWith("{") ||
        error.startsWith("<html>")) {
      return "Le service est momentanément indisponible. Patientez un peu puis réessayez.";
    }
    return error;
  }
}