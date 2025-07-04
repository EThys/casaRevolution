import 'dart:convert';

import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:provider/provider.dart';

class UserRegistrationPage extends StatefulWidget {
  @override
  _UserRegistrationPageState createState() => _UserRegistrationPageState();
}

class _UserRegistrationPageState extends State<UserRegistrationPage> {
  // Couleurs modernes
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF8F9FA);
  final Color _greyColor = Color(0xFF6C757D);
  final Color _successColor = Color(0xFF38B000);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFE9ECEF);
  final Color _errorColor = Color(0xFFD63031);

  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  final List<String> _genders = ['Homme', 'Femme'];
  final List<String> _rdcCities = [
    'Kinshasa', 'Lubumbashi', 'Mbuji-Mayi', 'Kananga', 'Kisangani',
    'Bukavu', 'Goma', 'Kolwezi', 'Likasi', 'Tshikapa',
    'Matadi', 'Kikwit', 'Uvira', 'Bunia', 'Mbandaka',
    'Butembo', 'Kalemie', 'Gbadolite', 'Isiro', 'Kindu',
    'Bandundu', 'Gemena', 'Mwene-Ditu', 'Kamina', 'Boma',
    'Kabinda', 'Lisala', 'Kipushi', 'Kasongo', 'Beni',
    'Mweka', 'Bumba', 'Kabalo', 'Luebo', 'Basoko',
    'Gandajika', 'Lodja', 'Dibaya', 'Demba', 'Kasangulu',
    'Lubao', 'Lusambo', 'Inongo', 'Kenge', 'Bolobo',
    'Businga', 'Bosobolo', 'Bongandanga', 'Bafwasende', 'Aketi'
  ];


  // Contrôleurs de formulaire
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _documentNumberController = TextEditingController();

  // États

  String? _selectedGender;
  String? _selectedCity = 'Kinshasa';
  bool _isLoading = false;
  bool _acceptTerms = false;
  bool _showPassword = false;
  File? _profileImage;
  File? _idCardFront;
  File? _idCardBack;
  final ImagePicker _picker = ImagePicker();
  String? _selectedAccountType;
  DateTime? _selectedDate;
  String? _selectedDocumentType = 'Carte d\'électeur';

  final Map<String, int> _accountTypes = {
    'Propriétaire': 1,
    'Locataire': 2,
    'Commissionnaire': 3,
  };

  final Map<String, int> _documentTypes = {
    'Carte d\'électeur': 1,
    'Passeport': 2,
    'Autres': 3,
  };

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // Modifiez votre méthode _pickImage pour réduire la qualité et la taille
  Future<void> _pickImage(ImageSource source, {bool isProfile = false, bool isFront = true}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Réduisez la qualité (70% au lieu de 85)
        maxWidth: 1024, // Limitez la largeur maximale
        maxHeight: 1024, // Limitez la hauteur maximale
      );

      if (image != null) {
        // Ajoutez un délai pour permettre au GC de fonctionner
        await Future.delayed(Duration(milliseconds: 100));

        if (!mounted) return;

        setState(() {
          if (isProfile) {
            _profileImage = File(image.path);
          } else if (isFront) {
            _idCardFront = File(image.path);
          } else {
            _idCardBack = File(image.path);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackbar("Erreur lors de la sélection de l'image", isError: true);
      print("Image picker error: $e");
    }
  }

  void _showImageSourceDialog({bool isProfile = false, bool isFront = true}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Choisir la source",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            SizedBox(height: 20),
            _buildImageSourceOption(
              icon: Icons.camera_alt,
              text: "Prendre une photo",
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isProfile: isProfile, isFront: isFront);
              },
            ),
            SizedBox(height: 16),
            Divider(height: 1, color: _borderColor),
            SizedBox(height: 16),
            _buildImageSourceOption(
              icon: Icons.photo_library,
              text: "Choisir depuis la galerie",
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isProfile: isProfile, isFront: isFront);
              },
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bio (optionnelle)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: _bioController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Décrivez-vous en quelques mots...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: _borderColor),
              ),
              filled: true,
              fillColor: _cardColor,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Genre',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedGender,
            items: _genders.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedGender = newValue;
              });
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: _borderColor),
              ),
              filled: true,
              fillColor: _cardColor,
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
              hintText: 'Sélectionnez',
            ),
            validator: (value) => value == null ? 'Requis' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ville',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedCity,
            items: _rdcCities.map((String city) {
              return DropdownMenuItem<String>(
                value: city,
                child: Text(city),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedCity = newValue;
              });
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: _borderColor),
              ),
              filled: true,
              fillColor: _cardColor,
              contentPadding: EdgeInsets.symmetric(horizontal: 10),
              hintText: '',
            ),
            validator: (value) => value == null ? 'Requis' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: _primaryColor, size: 24),
            SizedBox(width: 16),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: _darkColor,
              ),
            ),
            Spacer(),
            Icon(Icons.chevron_right, color: _greyColor),
          ],
        ),
      ),
    );
  }

  Future<bool> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _darkColor,
            ),
            dialogBackgroundColor: _cardColor,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      return true;
    }
    return false;
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? _errorColor : _successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        )
    );
    }

  Future<void> _handleRegister() async {
    // Activer la validation automatique
    setState(() {
      _autoValidateMode = AutovalidateMode.always;
    });

    // Attendre un court instant pour permettre à la validation de s'exécuter
    await Future.delayed(Duration(milliseconds: 50));

    // Validation du formulaire
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Vérification si le widget est monté ou si le chargement est déjà en cours
    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);

    // Masquer le clavier
    FocusScope.of(context).unfocus();

    // Vérification de la connexion internet
    final isConnected = await NetworkUtils.checkInternetConnectivity();
    if (!isConnected) {
      FancyNotification.show(context, "Pas de connexion internet");
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Convertir les images en base64
      String? profileImageBase64;
      String? idCardFrontBase64;
      String? idCardBackBase64;

      if (_profileImage != null) {
        final bytes = await _profileImage!.readAsBytes();
        profileImageBase64 = base64Encode(bytes);
      }

      if (_idCardFront != null) {
        final bytes = await _idCardFront!.readAsBytes();
        idCardFrontBase64 = base64Encode(bytes);
      }

      if (_idCardBack != null) {
        final bytes = await _idCardBack!.readAsBytes();
        idCardBackBase64 = base64Encode(bytes);
      }

      // Préparation des données utilisateur
      final userData = {
        "TypeAccountId": _accountTypes[_selectedAccountType], // 1, 2 ou 3
        "username": _emailController.text.split('@').first, // Généré à partir de l'email
        "email": _emailController.text,
        "CityId": 1, // À adapter selon vos villes
        "postal_code": "00000",
        "country": "Congo Kinshasa",
        "date_of_birth": _selectedDate != null
            ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
            : "1900-01-01",
        "gender": _selectedGender == "Homme" ? "male" : "female",
        "profile_picture": profileImageBase64 ?? "",
        "bio": _bioController.text,
        "is_agent": _selectedAccountType == "Commissionnaire" || _selectedAccountType == "Locataire",
        "is_admin": false,
        "password": _passwordController.text,
        "first_name": _firstNameController.text,
        "last_name": _lastNameController.text,
        "fullname": "${_firstNameController.text} ${_lastNameController.text}",
        "phone": _phoneController.text,
        "address": _addressController.text,
        "TypeCardId": _documentTypes[_selectedDocumentType], // 1, 2 ou 3
        "number_card": _documentNumberController.text,
        "note": "Nouveau membre", // Note par défaut
        "ParrainId": null, // ID du parrain si applicable
      };


      // Appel au contrôleur d'authentification
      final ctrl = context.read<AuthentificationCtrl>();
      final res = await ctrl.register(userData);

      if (!mounted) return;

      if (res.data['success'] == true) {
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
        String errorMessage = res.data['message'] ?? "Erreur lors de l'inscription";
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


  // void _submitForm() {
  //   if (_formKey.currentState!.validate()) {
  //
  //
  //     if (_selectedAccountType == null) {
  //       _showSnackbar("Veuillez sélectionner un type de compte", isError: true);
  //       return;
  //     }
  //
  //     // Vérification des documents seulement pour certains types de compte
  //     if ((_selectedAccountType == 'Propriètaire' || _selectedAccountType == 'Commissionnaire') &&
  //         (_idCardFront == null || _documentNumberController.text.isEmpty)) {
  //       _showSnackbar("Veuillez fournir les documents requis", isError: true);
  //       return;
  //     }
  //
  //
  //
  //     setState(() => _isLoading = true);
  //
  //     // Simuler un appel API
  //     Future.delayed(Duration(seconds: 2), () {
  //       setState(() => _isLoading = false);
  //
  //       final userData = {
  //         "first_name": _firstNameController.text,
  //         "last_name": _lastNameController.text,
  //         "phone": _phoneController.text,
  //         "email": _emailController.text,
  //         "birthDate": _selectedDate?.toIso8601String(),
  //         "address": _addressController.text,
  //         "bio": _bioController.text,
  //         "gender": _selectedGender,
  //         "country": "Congo Kinshasa",
  //         "city": _selectedCity,
  //         "account_type_id": _accountTypes[_selectedAccountType],
  //         "document_type_id": _documentTypes[_selectedDocumentType],
  //         "profileImage": _profileImage?.path,
  //         "document_number": _documentNumberController.text,
  //         "idCardFront": _idCardFront?.path,
  //         "idCardBack": _idCardBack?.path,
  //         "registrationDate": DateTime.now().toIso8601String(),
  //       };
  //
  //       _showSnackbar("Inscription réussie!");
  //       Navigator.pop(context, userData);
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          autovalidateMode: _autoValidateMode,
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section avantages
              _buildBenefitsSection(),
              SizedBox(height: 24),

              // Informations personnelles
              _buildSectionHeader('Informations personnelles'),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildModernTextField(
                      controller: _firstNameController,
                      label: 'Prénom',
                      hint: 'Jean',
                      icon: Icons.person_outline,
                      validator: (value) => value?.isEmpty ?? true ? 'Requis' : null,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildModernTextField(
                      controller: _lastNameController,
                      label: 'Nom',
                      hint: 'Dupont',
                      icon: Icons.supervised_user_circle_rounded,
                      validator: (value) => value?.isEmpty ?? true ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              _buildBirthDateField(),
              _buildModernTextField(
                controller: _phoneController,
                label: 'Téléphone',
                hint: '243810000000',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Requis';
                  if (value!.length < 9) return 'Numéro invalide';
                  return null;
                },
              ),
              _buildModernTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'jean.dupont@example.com',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Requis';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                    return 'Email invalide';
                  }
                  return null;
                },
              ),
              _buildModernTextField(
                controller: _addressController,
                label: 'Adresse',
                hint: '123 Avenue de la République, Kinshasa',
                icon: Icons.home_rounded,
                validator: (value) => value?.isEmpty ?? true ? 'Requis' : null,
              ),
              _buildBioField(),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildGenderDropdown(),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildCityDropdown(),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildProfileImageField(),
              SizedBox(height: 16),
              _buildAccountTypeDropdown(),

              // Documents
              if (_selectedAccountType == 'Propriétaire' || _selectedAccountType == 'Commissionnaire') ...[
                SizedBox(height: 10),
                _buildSectionHeader('Documents d\'identité'),
                SizedBox(height: 8),
                Text(
                  'Prenez des photos claires et lisibles de votre pièce d\'identité',
                  style: TextStyle(
                    color: _greyColor,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 16),
                _buildDocumentTypeSelector(),
                _buildDocumentNumberField(),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildDocumentUploadCard(
                        title: 'Recto*',
                        image: _idCardFront,
                        isRequired: true,
                        onTap: () => _showImageSourceDialog(isProfile: false, isFront: true),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildDocumentUploadCard(
                        title: 'Verso',
                        image: _idCardBack,
                        isRequired: false,
                        onTap: () => _showImageSourceDialog(isProfile: false, isFront: false),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Assurez-vous que toutes les informations sont visibles et lisibles',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              SizedBox(height: 24),

              // Sécurité
              _buildSectionHeader('Sécurité'),
              SizedBox(height: 16),
              _buildModernTextField(
                controller: _passwordController,
                label: 'Mot de passe',
                hint: '••••••••',
                icon: Icons.lock_outline,
                obscureText: !_showPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                    color: _greyColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Requis';
                  if (value!.length < 8) return '8 caractères minimum';
                  return null;
                },
              ),
              _buildModernTextField(
                controller: _confirmPasswordController,
                label: 'Confirmer le mot de passe',
                hint: '••••••••',
                icon: Icons.lock_outline,
                obscureText: !_showPassword,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Requis';
                  if (value != _passwordController.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),

              // Conditions
              _buildTermsCheckbox(),
              SizedBox(height: 24),

              // Bouton d'inscription
              _buildSubmitButton(),
              SizedBox(height: 20),

              // Lien de connexion
              Center(
                child: TextButton(
                  onPressed: () {
                   Navigator.pushNamed(context, Routes.loginRoute);
                  },
                  child: RichText(
                    text: TextSpan(
                      text: "Déjà un compte ? ",
                      style: TextStyle(color: _greyColor),
                      children: [
                        TextSpan(
                          text: "Connectez-vous",
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: _primaryColor),
              SizedBox(width: 8),
              Text(
                'Avantages avec un compte',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildBenefitItem('✓ Recherches avancées et filtres personnalisés'),
          _buildBenefitItem('✓ Organisation des visites terrain'),
          _buildBenefitItem('✓ Sauvegarde de vos propriétés favorites'),
          _buildBenefitItem('✓ Notifications instantanées pour nouveaux biens'),
          SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(color: _darkColor),
              children: [
                TextSpan(text: 'Abonnement premium à seulement '),
                TextSpan(
                  text: '5\$ par an',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                TextSpan(text: ' pour accéder à toutes les fonctionnalités'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: _successColor, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: _darkColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photo de profil (optionnelle)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showImageSourceDialog(isProfile: true),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _borderColor),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.camera_alt, color: _greyColor, size: 24),
                SizedBox(width: 16),
                Text(
                  _profileImage == null
                      ? 'Ajouter une photo'
                      : 'Photo sélectionnée',
                  style: TextStyle(
                    color: _greyColor,
                  ),
                ),
                Spacer(),
                if (_profileImage != null)
                  Icon(Icons.check_circle, color: _successColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de compte*',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedAccountType,
            items: _accountTypes.keys.map((String key) {
              return DropdownMenuItem<String>(
                value: key, // On utilise la clé comme valeur
                child: Text(key), // On affiche le libellé
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedAccountType = newValue;
              });
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: _borderColor),
              ),
              filled: true,
              fillColor: _cardColor,
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
              hintText: 'Sélectionnez un type',
            ),
            validator: (value) => value == null ? 'Requis' : null,
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Créer un compte',
        style: TextStyle(
          color: _darkColor,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: _darkColor, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _darkColor,
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController? controller,
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
    int maxLines = 1,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: _greyColor) : null,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: _borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: _borderColor),
          ),
          filled: true,
          fillColor: _cardColor,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines == 1 ? 0 : 16,
          ),
          labelStyle: TextStyle(color: _greyColor),
        ),
      ),
    );
  }

  Widget _buildBirthDateField() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: TextFormField(
        controller: _birthDateController,
        readOnly: true, // Empêche l'édition manuelle
        decoration: InputDecoration(
          labelText: 'Date de naissance',
          hintText: 'JJ/MM/AAAA',
          prefixIcon: Icon(Icons.calendar_today, color: _greyColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: _borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: _borderColor),
          ),
          filled: true,
          fillColor: _cardColor,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
          labelStyle: TextStyle(color: _greyColor),
          suffixIcon: IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ),
        validator: (value) {
          if (value?.isEmpty ?? true) {
            return 'Requis';
          }
          return null;
        },
        onTap: () => _selectDate(context),
      ),
    );
  }

  Widget _buildDocumentNumberField() {
    return _buildModernTextField(
      controller: _documentNumberController,
      label: 'Numéro du document',
      hint: 'Entrez le numéro de votre pièce',
      icon: Icons.credit_card_rounded,
      validator: (value) {
        if ((_selectedAccountType == 'Propriétaire' || _selectedAccountType == 'Commissionnaire') &&
            (value?.isEmpty ?? true)) {
          return 'Ce champ est requis';
        }
        return null;
      },
    );
  }

  Widget _buildDocumentTypeSelector() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedDocumentType,
        items: _documentTypes.keys.map((String key) {
          return DropdownMenuItem<String>(
            value: key, // On utilise la clé comme valeur
            child: Text(key), // On affiche le libellé
          );
        }).toList(),
        onChanged: (newValue) {
          setState(() {
            _selectedDocumentType = newValue;
          });
        },
        decoration: InputDecoration(
          labelText: 'Type de document',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: _borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: _borderColor),
          ),
          filled: true,
          fillColor: _cardColor,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
          labelStyle: TextStyle(color: _greyColor),
        ),
        validator: (value) {
          if ((_selectedAccountType == 'Propriétaire' || _selectedAccountType == 'Commissionnaire') &&
              value == null) {
            return 'Requis';
          }
          return null;
        },
      ),
    );
  }

  // Widget _buildAccountTypeSelector() {
  //   return Wrap(
  //     spacing: 8,
  //     runSpacing: 8,
  //     children: _accountTypes.map((type) {
  //       final isSelected = _selectedAccountType == type;
  //       return ChoiceChip(
  //         label: Text(
  //           type,
  //           style: TextStyle(
  //             color: isSelected ? Colors.white : _darkColor,
  //             fontWeight: FontWeight.w500,
  //           ),
  //         ),
  //         selected: isSelected,
  //         onSelected: (selected) {
  //           setState(() {
  //             _selectedAccountType = selected ? type : null;
  //           });
  //         },
  //         selectedColor: _primaryColor,
  //         backgroundColor: _cardColor,
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(20),
  //           side: BorderSide(color: _borderColor),
  //         ),
  //         elevation: isSelected ? 2 : 0,
  //         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //         labelPadding: EdgeInsets.symmetric(horizontal: 4),
  //       );
  //     }).toList(),
  //   );
  // }

  Widget _buildDocumentUploadCard({
    required String title,
    required File? image,
    required bool isRequired,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRequired) // Afficher le validateur seulement si le champ est requis
          FormField<bool>(
            builder: (formFieldState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _darkColor,
                      ),
                      children: [
                        TextSpan(
                          text: '*',
                          style: TextStyle(color: _errorColor),
                        )
                      ],
                    ),
                  ),
                  if (formFieldState.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        formFieldState.errorText!,
                        style: TextStyle(
                          color: _errorColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              );
            },
            validator: (value) {
              if (isRequired && image == null) {
                return 'Ce document est requis';
              }
              return null;
            },
          )
        else
          RichText(
            text: TextSpan(
              text: title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _darkColor,
              ),
            ),
          ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: image == null ? _lightColor : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: image == null ? _borderColor : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: image == null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo,
                    color: _greyColor,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    title.contains('Recto') ? 'Recto' : 'Verso',
                    style: TextStyle(
                      color: _greyColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(image, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title.replaceAll('*', '').trim(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.white, size: 20),
                          onPressed: () {
                            setState(() {
                              if (title.contains('Recto')) {
                                _idCardFront = null;
                              } else {
                                _idCardBack = null;
                              }
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return FormField<bool>(
      builder: (formFieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _acceptTerms ? _primaryColor : _cardColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _acceptTerms ? _primaryColor : _borderColor,
                      width: 2,
                    ),
                  ),
                  child: Checkbox(
                    value: _acceptTerms,
                    onChanged: (value) {
                      setState(() {
                        _acceptTerms = value ?? false;
                        formFieldState.didChange(value);
                      });
                    },
                    activeColor: Colors.transparent,
                    checkColor: Colors.white,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide.none,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: _greyColor, fontSize: 13),
                      children: [
                        TextSpan(text: "J'accepte les "),
                        TextSpan(
                          text: "conditions d'utilisation",
                          style: TextStyle(
                            color: _primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(text: " et la "),
                        TextSpan(
                          text: "politique de confidentialité",
                          style: TextStyle(
                            color: _primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(text: "*"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (formFieldState.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 4),
                child: Text(
                  formFieldState.errorText!,
                  style: TextStyle(
                    color: _errorColor,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
      validator: (value) {
        if (value == null || !value) {
          return 'Vous devez accepter les conditions';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _handleRegister,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: Size(double.infinity, 50),
      ),
      child: _isLoading
          ? SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Colors.white,
        ),
      )
          : Text(
        'Créer mon compte',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }


}








