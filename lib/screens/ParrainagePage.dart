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
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:casa/widgets/step_appear.dart';

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

  /// 0 programme, 1 nom, 2 contact, 3 ville, 4 type de compte, 5 parrain, 6 mot de passe.
  int _parrainageStep = 0;
  static const int _stepCount = 7;
  bool _isImmobilierDropdownOpen = false;
  bool _isServicesDropdownOpen = false;
  bool _showConditionsError = false;

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

  void _previousStep() {
    FocusScope.of(context).unfocus();
    if (_parrainageStep == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _parrainageStep -= 1);
  }

  void _continueStep() {
    FocusScope.of(context).unfocus();
    if (_parrainageStep == 0 || _parrainageStep == 5) {
      setState(() => _parrainageStep += 1);
      return;
    }
    if (_parrainageStep == 1) {
      setState(() {
        _firstNameTouched = true;
        _lastNameTouched = true;
      });
      if (_validateName(_firstNameController.text, 'prénom') != null ||
          _validateName(_lastNameController.text, 'nom') != null) {
        return;
      }
    } else if (_parrainageStep == 2) {
      setState(() => _contactTouched = true);
      if (_validateContact(_contactController.text) != null) return;
    } else if (_parrainageStep == 3) {
      setState(() => _cityTouched = true);
      if (_validateCity(_cityController.text) != null) return;
    } else if (_parrainageStep == 4) {
      final hasAccount = _isLocataireSelected ||
          _selectedOwnerAccountId != null ||
          _selectedPrestataireAccountId != null;
      if (!hasAccount) {
        setState(() => _autoValidateMode = AutovalidateMode.always);
        return;
      }
    } else {
      setState(() => _passwordTouched = true);
      if (_validatePassword(_passwordController.text) != null) return;
      if (!_acceptConditions) {
        setState(() => _showConditionsError = true);
        return;
      }
      _handleRegister();
      return;
    }
    setState(() => _parrainageStep += 1);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: PopScope(
        canPop: _parrainageStep == 0 && !_isLoading,
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: SingleChildScrollView(
                      key: ValueKey<int>(_parrainageStep),
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                      child: _buildStepBody(),
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
                    ),
                  ),
                ),
                Text(
                  '${_parrainageStep + 1}/$_stepCount',
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
                final filled = index <= _parrainageStep;
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

  Widget _buildStepBody() {
    late final String title;
    late final String subtitle;
    late final Widget fields;
    switch (_parrainageStep) {
      case 0:
        title = 'Parrainer, c’est grandir ensemble';
        subtitle = 'Invitez vos proches et participez au tirage CasaNayo.';
        fields = _buildParrainageBenefits();
        break;
      case 1:
        title = 'Comment vous appelez-vous ?';
        subtitle = 'Ces informations apparaîtront sur votre profil.';
        fields = _buildStep1FormFields();
        break;
      case 2:
        title = 'Comment peut-on vous joindre ?';
        subtitle = 'Un email ou un numéro de téléphone suffit.';
        fields = _buildContactField();
        break;
      case 3:
        title = 'Dans quelle ville êtes-vous ?';
        subtitle = 'Pour vous proposer des biens près de chez vous.';
        fields = _buildCityField();
        break;
      case 4:
        title = 'Que venez-vous faire ?';
        subtitle = 'Choisissez le type de compte qui vous correspond.';
        fields = _buildAccountTypeField();
        break;
      case 5:
        title = 'Qui vous a parrainé ?';
        subtitle = 'Recherchez son nom. Vous pouvez aussi passer cette étape.';
        fields = _buildParrainField();
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
      key: ValueKey<int>(_parrainageStep),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.35),
        ),
        const SizedBox(height: 28),
        fields,
      ],
    ),
    );
  }

  Widget _buildStepButton() {
    final isLast = _parrainageStep == _stepCount - 1;
    final label = _parrainageStep == 0
        ? 'Commencer'
        : (isLast ? 'Créer mon compte' : 'Suivant');
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
      ),
    );
  }

  Widget _stepNavRow({required VoidCallback onBack, required VoidCallback onNext}) {
    return Row(
      children: [
        Expanded(child: _pillOutline('Retour', onBack)),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: _pillPrimary('Continuer', onNext)),
      ],
    );
  }

  Widget _pillPrimary(String label, VoidCallback onPressed) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _pillOutline(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _twTextPrimary,
        side: const BorderSide(color: _twBorder),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _benefitRow({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prizeChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: primaryColor,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildParrainageBenefits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '5 filleuls',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'pour entrer dans le tirage CasaNayo.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _benefitRow(
          icon: Icons.group_add_rounded,
          title: 'Invitez vos proches',
          body: 'Dès 5 inscriptions grâce à vous, vous devenez éligible au tirage.',
        ),
        _benefitRow(
          icon: Icons.workspace_premium_rounded,
          title: 'Les abonnements comptent',
          body: 'Si un filleul prend un abonnement annuel, vos chances augmentent.',
        ),
        _benefitRow(
          icon: Icons.emoji_events_rounded,
          title: 'Des lots à gagner',
          body: 'Les gagnants reçoivent une récompense tirée au sort.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _prizeChip('Bons d’achat'),
            _prizeChip('Forfaits internet'),
            _prizeChip('Véhicules'),
          ],
        ),
      ],
    );
  }

  Widget _buildStepProgressBar() {
    final stepIndex = _parrainageStep.clamp(0, 3);
    return Row(
      children: List.generate(4, (i) {
        final done = i < stepIndex;
        final current = i == stepIndex;
        final active = done || current;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? primaryColor : Colors.white,
                  border: Border.all(color: active ? primaryColor : _twBorder, width: 1.5),
                ),
                child: done
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: current ? Colors.white : _twTextSecondary,
                        ),
                      ),
              ),
              if (i < 3)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: i < stepIndex ? primaryColor : _twBorder,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  String _parrainInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Widget _parrainAvatar(String name, {double size = 42}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        _parrainInitials(name),
        style: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
        ),
      ),
    );
  }

  void _selectParrain(Map<String, dynamic> parrain) {
    setState(() {
      _selectedParrain = parrain;
      _parrainSearchController.text = (parrain['name'] as String?) ?? '';
      _isSearchingParrains = false;
      _filteredParrains = [];
    });
    _parrainFocus.unfocus();
  }

  void _clearParrain() {
    setState(() {
      _selectedParrain = null;
      _parrainSearchController.clear();
      _isSearchingParrains = false;
      _filteredParrains = [];
    });
  }

  Widget _buildParrainField() {
    final query = _parrainSearchController.text.trim();
    final showResults = _selectedParrain == null && _isSearchingParrains && query.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedParrain != null)
          _buildSelectedParrainCard()
        else ...[
          TextField(
            controller: _parrainSearchController,
            focusNode: _parrainFocus,
            style: TextStyle(color: textColor, fontSize: 16),
            onTapOutside: (_) => _parrainFocus.unfocus(),
            onChanged: (value) {
              if (_selectedParrain != null) {
                final selName = (_selectedParrain!['name'] as String?)?.trim() ?? '';
                if (value.trim() != selName) {
                  setState(() => _selectedParrain = null);
                }
              }
              _searchParrains(value);
            },
            decoration: InputDecoration(
              hintText: _loadingParrainUsers ? 'Chargement des membres…' : 'Rechercher un nom',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
              prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                      onPressed: _clearParrain,
                    )
                  : (_loadingParrainUsers
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(showResults ? 18 : 16),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(showResults ? 18 : 16),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showResults ? _buildParrainResults() : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 12),
          const Text(
            'Cette étape est facultative. Vous pouvez continuer sans parrain.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.35),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedParrainCard() {
    final name = (_selectedParrain!['name'] as String?) ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor, width: 1.5),
      ),
      child: Row(
        children: [
          _parrainAvatar(name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Parrain choisi',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1976D2)),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                Text(
                  _parrainPublicSubtitle(_selectedParrain!),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _clearParrain,
            child: Text('Changer', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildParrainResults() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _filteredParrains.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Text(
                'Aucun membre ne correspond à cette recherche.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _filteredParrains.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final parrain = _filteredParrains[index];
                  final name = (parrain['name'] as String?) ?? '';
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _selectParrain(parrain),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          _parrainAvatar(name, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _parrainPublicSubtitle(parrain),
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

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
          selectedLabel: _labelFor(typeCtrl.ownerTypes, _selectedOwnerAccountId),
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
          selectedLabel: _labelFor(typeCtrl.serviceTypes, _selectedPrestataireAccountId),
          onToggle: () => _toggleTypeMenu(immobilier: false, typeCtrl: typeCtrl),
          options: typeCtrl.serviceTypes,
          selectedId: _selectedPrestataireAccountId,
          onSelected: (id) {
            setState(() {
              _selectedPrestataireAccountId = _selectedPrestataireAccountId == id ? null : id;
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
            child: Text(
              'Sélectionnez au moins une catégorie',
              style: TextStyle(color: errorColor, fontSize: 13, fontWeight: FontWeight.w600),
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
          color: selected ? primaryColor.withOpacity(0.08) : Colors.white,
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
                  const Text(
                    'Locataire',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 2),
                  Text('Je cherche un logement', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
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
        FancyNotification.show(
          context,
          immobilier
              ? "Les types de compte immobilier ne sont pas disponibles pour le moment."
              : "Les types de service ne sont pas disponibles pour le moment.",
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
                          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                          const SizedBox(height: 2),
                          Text(
                            hasSelection ? selectedLabel : hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: hasSelection ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: expandDuration,
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: open ? primaryColor : Colors.grey[500]),
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
                        for (var i = 0; i < options.length; i++)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final id = _optionId(options[i]);
                              if (id != null) onSelected(id);
                            },
                            child: Container(
                              color: _optionId(options[i]) == selectedId
                                  ? primaryColor.withOpacity(0.14)
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              child: Row(
                                children: [
                                  Icon(
                                    _optionId(options[i]) == selectedId
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: _optionId(options[i]) == selectedId
                                        ? primaryColor
                                        : const Color(0xFFD1D5DB),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _optionName(options[i]).isEmpty ? 'Type' : _optionName(options[i]),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                      ? (ready ? successColor : primaryColor)
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
            color: ready ? successColor : secondaryTextColor,
          ),
        ),
      ],
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
          isTouched: _lastNameTouched,
          onChanged: (val) {
            if (!_lastNameTouched && val.isNotEmpty) {
              setState(() => _lastNameTouched = true);
            }
          },
        ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'J\'accepte les ',
                          style: TextStyle(color: Color(0xFF334155), fontSize: 14, height: 1.35),
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
                          style: TextStyle(color: Color(0xFF334155), fontSize: 14, height: 1.35),
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
                          style: TextStyle(color: Color(0xFF334155), fontSize: 14, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (showError)
            const Padding(
              padding: EdgeInsets.only(left: 12, right: 4, top: 4),
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
    );
  }

  Widget _buildAuthCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepProgressBar(),
        const SizedBox(height: 18),
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
              'Quatre étapes, comme un fil. Ensuite vous créez le compte avec le nom de votre parrain.',
              textAlign: TextAlign.left,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: _twTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _buildParrainageBenefits(),
          ] else if (_parrainageStep == 1) ...[
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
                  ],
                ),
              ),
            ),
          ] else if (_parrainageStep == 2) ...[
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
                ],
              ),
            ),
          ] else ...[
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
              'Choisissez votre parrain, puis le mot de passe du compte.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                color: _twTextSecondary,
              ),
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 12),
            _buildLoginLink(),
          ],
      ],
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
        onFieldSubmitted: (_) => _continueStep(),
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

  Widget _buildAuthButton() {
    final hasRequiredFields = _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty &&
        _contactController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty;

    final isFormValid = _isFormValid();
    final isButtonEnabled = hasRequiredFields && isFormValid && _acceptConditions && !_isLoading;

    return FilledButton(
      onPressed: isButtonEnabled ? _handleRegister : null,
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        disabledBackgroundColor: primaryColor.withOpacity(0.35),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white70,
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(
              'Créer mon compte',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
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
      setState(() => _showConditionsError = true);
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