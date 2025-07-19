import 'dart:convert';

import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/utils/Endpoints.dart';
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

class ParrainagePage extends StatefulWidget {
  @override
  _ParrainagePageState createState() => _ParrainagePageState();
}

class _ParrainagePageState extends State<ParrainagePage> {

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: _greyColor,
        fontSize: 14,
      ),
      floatingLabelStyle: TextStyle(
        color: _primaryColor,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
      filled: true,
      fillColor: _cardColor,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: Icon(Icons.arrow_drop_down_rounded, color: _greyColor),
    );
  }
  // Couleurs modernes
  final Color _primaryColor = Color(0xFF4361EE); // Bleu vif mais professionnel
  final Color _secondaryColor = Color(0xFF3F37C9); // Bleu foncé
  final Color _accentColor = Color(0xFF4CC9F0); // Bleu clair
  final Color _darkColor = Color(0xFF1A1D26); // Noir profond
  final Color _lightColor = Color(0xFFF8F9FA); // Blanc cassé
  final Color _greyColor = Color(0xFF6C757D); // Gris moyen
  final Color _lightGrey = Color(0xFFE9ECEF); // Gris très clair
  final Color _successColor = Color(0xFF38B000); // Vert
  final Color _errorColor = Color(0xFFD63031); // Rouge
  final Color _cardColor = Colors.white; // Blanc pur
  final Color _borderColor = Color(0xFFE9ECEF);
  final Color _textColor = Color(0xFF495057); // Gris foncé pour texte

  // Styles de texte réutilisables
  final TextStyle _headerStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: Colors.black87,
  );

  final TextStyle _sectionTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
    letterSpacing: 0.5,
  );

  final TextStyle _labelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  final TextStyle _hintStyle = TextStyle(
    fontSize: 14,
    color: Color(0xFFADB5BD),
  );

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

  Future<void> _pickImage(ImageSource source, {bool isProfile = false, bool isFront = true}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Choisir la source",
              style: _sectionTitleStyle.copyWith(fontSize: 20),
            ),
            SizedBox(height: 20),
            _buildImageSourceOption(
              icon: Icons.camera_alt,
              text: "Prendre une photo",
              color: _primaryColor,
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isProfile: isProfile, isFront: isFront);
              },
            ),
            SizedBox(height: 16),
            Divider(height: 1, color: _lightGrey),
            SizedBox(height: 16),
            _buildImageSourceOption(
              icon: Icons.photo_library,
              text: "Choisir depuis la galerie",
              color: _secondaryColor,
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

  Widget _buildImageSourceOption({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 16),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: _darkColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            Spacer(),
            Icon(Icons.chevron_right, color: _greyColor),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsSection() {
    return Container(
      padding: EdgeInsets.all(20),
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor.withOpacity(0.05),
            _accentColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star_rounded, color: _primaryColor, size: 24),
              ),
              SizedBox(width: 12),
              Text(
                'Avantages du parrainage',
                style: _headerStyle.copyWith(fontSize: 18, color: _primaryColor),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildBenefitItem('✓ Un compte actif pour publier ses propriétés'),
          _buildBenefitItem('✓ Sa première publication offerte'),
          _buildBenefitItem('✓ Un abonnement à seulement 5\$ par an pour les publications suivantes'),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Vous serez rémunéré pour chaque bailleur actif que vous parrainez.',
              style: TextStyle(
                color: _primaryColor,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: _successColor, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _textColor,
                fontSize: 14,
                height: 1.4,
              ),
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
          style: _labelStyle,
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showImageSourceDialog(isProfile: true),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _lightGrey),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                )
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.camera_alt, color: _greyColor, size: 24),
                SizedBox(width: 16),
                Text(
                  _profileImage == null ? 'Ajouter une photo' : 'Photo sélectionnée',
                  style: TextStyle(color: _greyColor),
                ),
                Spacer(),
                if (_profileImage != null)
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _successColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: _successColor, size: 18),
                  ),
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
          style: _labelStyle,
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
                value: key,
                child: Text(
                  key,
                  style: TextStyle(
                    fontSize: 15,
                    color: _darkColor,
                  ),
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedAccountType = newValue;
              });
            },
            decoration: _dropdownDecoration(''),
            style: TextStyle(
              fontSize: 15,
              color: _darkColor,
            ),
            icon: SizedBox.shrink(),
            dropdownColor: _cardColor,
            borderRadius: BorderRadius.circular(12),
            menuMaxHeight: 250,
            isExpanded: true,
            validator: (value) => value == null ? 'Ce champ est requis' : null,
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Parrainer un membre',
        style: _headerStyle.copyWith(
          color: _darkColor,
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
      flexibleSpace: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: _lightGrey,
                width: 1
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: _sectionTitleStyle,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
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
          prefixIcon: icon != null ? Icon(icon, color: Color(0xFF6C757D)) : null,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          labelStyle: TextStyle(color: Color(0xFF6C757D)),
        ),
      ),
    );
  }


  Widget _buildBirthDateField() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date de naissance*',
            style: _labelStyle,
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: () => _selectDate(context),
            child: Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _birthDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'JJ/MM/AAAA',
                    hintStyle: _hintStyle,
                    prefixIcon: Icon(Icons.calendar_today, color: _greyColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _lightGrey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _lightGrey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primaryColor, width: 1.5),
                    ),
                    filled: true,
                    fillColor: _cardColor,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Requis';
                    }
                    return null;
                  },
                ),
              ),
            ),
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de document*',
          style: _labelStyle,
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
                value: key,
                child: Text(
                  key,
                  style: TextStyle(
                    fontSize: 15,
                    color: _darkColor,
                  ),
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedDocumentType = newValue;
              });
            },
            decoration: _dropdownDecoration(''),
            style: TextStyle(
              fontSize: 15,
              color: _darkColor,
            ),
            icon: SizedBox.shrink(),
            dropdownColor: _cardColor,
            borderRadius: BorderRadius.circular(12),
            menuMaxHeight: 250,
            isExpanded: true,
            validator: (value) {
              if ((_selectedAccountType == 'Propriétaire' ||
                  _selectedAccountType == 'Commissionnaire') &&
                  value == null) {
                return 'Ce champ est requis';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentUploadCard({
    required String title,
    required File? image,
    required bool isRequired,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRequired)
          FormField<bool>(
            builder: (formFieldState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: title,
                      style: _labelStyle,
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
          Text(title, style: _labelStyle),
        SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: image == null ? _lightColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: image == null ? _lightGrey : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                if (image != null)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
              ],
            ),
            child: image == null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_a_photo,
                      color: _primaryColor,
                      size: 28,
                    ),
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
              borderRadius: BorderRadius.circular(12),
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
                          Colors.black.withOpacity(0.6),
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
                          icon: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.delete,
                                color: Colors.white, size: 18),
                          ),
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
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _acceptTerms = !_acceptTerms;
                      formFieldState.didChange(_acceptTerms);
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _acceptTerms ? _primaryColor : _cardColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _acceptTerms ? _primaryColor : _lightGrey,
                        width: 2,
                      ),
                    ),
                    child: _acceptTerms
                        ? Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
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
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(text: " et la "),
                        TextSpan(
                          text: "politique de confidentialité",
                          style: TextStyle(
                            color: _primaryColor,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
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
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Parrainer',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Genre*',
          style: _labelStyle,
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: _darkColor,
                  ),
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedGender = newValue;
              });
            },
            decoration: _dropdownDecoration(''),
            style: TextStyle(
              fontSize: 15,
              color: _darkColor,
            ),
            icon: SizedBox.shrink(),
            dropdownColor: _cardColor,
            borderRadius: BorderRadius.circular(12),
            menuMaxHeight: 250,
            isExpanded: true,
            validator: (value) => value == null ? 'Ce champ est requis' : null,
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
          'Ville*',
          style: _labelStyle,
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedCity,
            items: _rdcCities.map((String city) {
              return DropdownMenuItem<String>(
                value: city,
                child: Text(
                  city,
                  style: TextStyle(
                    fontSize: 15,
                    color: _darkColor,
                  ),
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedCity = newValue;
              });
            },
            decoration: _dropdownDecoration(''),
            style: TextStyle(
              fontSize: 15,
              color: _darkColor,
            ),
            icon: SizedBox.shrink(),
            dropdownColor: _cardColor,
            borderRadius: BorderRadius.circular(12),
            menuMaxHeight: 250,
            isExpanded: true,
            validator: (value) => value == null ? 'Ce champ est requis' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bio (optionnelle)',
          style: _labelStyle,
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: TextFormField(
            controller: _bioController,
            maxLines: 3,
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              hintText: 'Décrivez-vous en quelques mots...',
              hintStyle: _hintStyle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _lightGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _lightGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 1.5),
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

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _errorColor : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _handleRegister() async {
    setState(() {
      _autoValidateMode = AutovalidateMode.always;
    });

    await Future.delayed(Duration(milliseconds: 50));

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

    try {
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

      final userData = {
        "TypeAccountId": _accountTypes[_selectedAccountType],
        "username": _emailController.text.split('@').first,
        "email": _emailController.text,
        "CityId": 1,
        "postal_code": "00000",
        "country": "Congo Kinshasa",
        "date_of_birth": _selectedDate != null
            ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
            : "1900-01-01",
        "gender": _selectedGender == "Homme" ? "male" : "female",
        "profile_picture": profileImageBase64 ?? "",
        "images": profileImageBase64 ?? "",
        "card_front":idCardFrontBase64 ?? "",
        "card_back":idCardBackBase64 ?? "",
        "bio": _bioController.text,
        "is_agent": _selectedAccountType == "Commissionnaire" || _selectedAccountType == "Locataire",
        "is_admin": false,
        "password": _passwordController.text,
        "first_name": _firstNameController.text,
        "last_name": _lastNameController.text,
        "fullname": "${_firstNameController.text} ${_lastNameController.text}",
        "phone": _phoneController.text,
        "address": _addressController.text,
        "TypeCardId": _documentTypes[_selectedDocumentType],
        "number_card": _documentNumberController.text,
        "note": "Nouveau membre",
        "ParrainId": 1,
      };

      String registerUrl;

      switch (_selectedAccountType) {
        case 'Propriétaire':
          registerUrl = "${Endpoints.bailleur}";
          break;
        case 'Locataire':
          registerUrl = "${Endpoints.locataire}";
          break;
        case 'Commissionnaire':
          registerUrl = "${Endpoints.commissionnaire}";
          break;
        default:
          registerUrl = Endpoints.register;
      }

      final ctrl = context.read<AuthentificationCtrl>();
      final res = await ctrl.register(userData, url: registerUrl);

      if (!mounted) return;

      if (res.data['success'] == true) {
        FancyNotification.show(context, "Inscription réussie!", isError: false);
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          // String routeName
          //
          // // Déterminer la route en fonction du type de compte
          // switch (_selectedAccountType) {
          //   case 'Propriétaire':
          //     routeName = Routes.BailleurRoute;
          //     break;
          //   case 'Locataire':
          //     routeName = Routes.LocataireRoute;
          //     break;
          //   case 'Commissionnaire':
          //     routeName = Routes.CommissionnaireRoute;
          //     break;
          //   default:
          //     routeName = Routes.loginRoute;
          // }

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
                SizedBox(height: 16),
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
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }





}