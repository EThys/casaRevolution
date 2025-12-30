import 'dart:convert';
import 'dart:io';

import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/utils/AppColors.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../camera/SelfieCameraScreen.dart';

class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({Key? key}) : super(key: key);

  @override
  State<IdentityVerificationPage> createState() => _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _addressController = TextEditingController();
  final _cardNumberController = TextEditingController();
  
  // State
  String? _selectedCardType; // "Passeport", "Permis de conduire", "Carte d'électeur"
  File? _imageProfile; // Photo de profil
  File? _imageFront;
  File? _imageBack;
  bool _isLoading = false;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec les infos utilisateur si disponibles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authCtrl = context.read<AuthentificationCtrl>();
      if (authCtrl.user.city != null) {
        _addressController.text = authCtrl.user.city ?? "";
      }
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cardNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isProfile, {bool isFront = true}) async {
    try {
      if (isProfile) {
        // Enforce Selfie Camera only
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelfieCameraScreen(
              onImageCaptured: (path) {
                setState(() {
                  _imageProfile = File(path);
                });
              },
            ),
          ),
        );
        return;
      }

      // For ID cards, allow standard camera (usually rear)
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera, // Always camera for ID
        imageQuality: 70,
        maxWidth: 1024,
      );
      
      if (photo != null) {
        setState(() {
          if (isFront) {
            _imageFront = File(photo.path);
          } else {
            _imageBack = File(photo.path);
          }
        });
      }
    } catch (e) {
      print("Erreur choix image: $e");
      FancyNotification.show(context, "Impossible d'accéder à la caméra", isError: true);
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_imageProfile == null) {
       FancyNotification.show(context, "Veuillez ajouter une photo de profil", isError: true);
       return;
    }

    // Vérifier le type de carte pour déterminer si le verso est requis
    int typeCardId = 0;
    switch (_selectedCardType) {
      case 'Passeport': typeCardId = 1; break;
      case 'Permis de conduire': typeCardId = 2; break;
      case "Carte d'électeur": typeCardId = 3; break;
      default: typeCardId = 1;
    }
    
    if (_imageFront == null) {
      FancyNotification.show(context, "Veuillez ajouter la photo recto de votre pièce d'identité", isError: true);
      return;
    }
    
    // Pour le passeport (typeCardId = 1), le verso n'est pas requis
    if (typeCardId != 1 && _imageBack == null) {
      FancyNotification.show(context, "Veuillez ajouter la photo verso de votre pièce d'identité", isError: true);
      return;
    }
    
    setState(() => _isLoading = true);

    if (!await NetworkUtils.checkInternetConnectivity()) {
      setState(() => _isLoading = false);
      FancyNotification.show(context, "Pas de connexion internet", isError: true);
      return;
    }

    try {
      final authCtrl = context.read<AuthentificationCtrl>();
      if (authCtrl.user.userId == null) {
        throw Exception("Utilisateur non identifié");
      }

      // Utiliser l'ID du profil (profile.id) et non userId pour l'URL /api/members/{profileId}
      final profileData = authCtrl.stockage?.read(StockageKeys.profileKey);
      int? profileId;
      
      if (profileData != null && profileData is Map) {
        profileId = profileData['id'];
      }
      
      // Si pas de profileId, utiliser userId comme fallback
      final targetId = profileId?.toString() ?? authCtrl.user.userId?.toString();
      
      if (targetId == null) {
        throw Exception("Impossible de déterminer l'ID du profil");
      }

      // 1. D'abord, uploader l'image de profil via l'endpoint séparé /api/members/{id}/profile
      String profileBase64 = base64Encode(await _imageProfile!.readAsBytes());
      final profileImageResponse = await authCtrl.updateProfilePicture(targetId, profileBase64);
      
      if (!profileImageResponse.status) {
        FancyNotification.show(
          context,
          profileImageResponse.errorMsg ?? "Erreur lors de l'upload de la photo de profil",
          type: NotificationType.error,
        );
        setState(() => _isLoading = false);
        return;
      }
      
      print("✅ Image de profil uploadée avec succès");

      // 2. Ensuite, envoyer la vérification d'identité (sans l'image de profil dans le payload)
      String frontBase64 = base64Encode(await _imageFront!.readAsBytes());
      // Pour le passeport, le verso peut être vide
      String backBase64 = _imageBack != null 
          ? base64Encode(await _imageBack!.readAsBytes())
          : "";
      
      // Récupération des noms depuis le profil existant (ou vide si manquant)
      String firstName = "";
      String lastName = "";
      
      try {
        if (profileData != null && profileData is Map) {
          firstName = profileData['firstname'] ?? "";
          lastName = profileData['lastname'] ?? "";
        }
      } catch (e) {
        print("Erreur lecture profile keys: $e");
      }
      
      // Fallback if empty
      if (firstName.isEmpty) firstName = authCtrl.user.username ?? "";

      // Récupérer les données utilisateur depuis le stockage
      final userData = authCtrl.stockage?.read(StockageKeys.userKey) ?? {};
      
      // Structure du payload pour la vérification (sans l'image de profil qui est déjà uploadée)
      final payload = {
        "lastName": lastName,
        "firstName": firstName,
        "address": _addressController.text,
        // "images" n'est plus dans le payload car l'image de profil est uploadée séparément
        "cardFront": frontBase64,
        "cardBack": backBase64,
        "typeCardId": typeCardId,
        "parrainId": 0,
        "numberCard": _cardNumberController.text,
        // La clé "user" doit toujours être présente avec toutes ses propriétés (même vides)
        "user": {
          "email": (userData['email']?.toString() ?? "").isEmpty ? "string" : userData['email']?.toString() ?? "",
          "phone": userData['phone']?.toString() ?? "",
          "city": userData['city']?.toString() ?? "",
          "country": userData['country']?.toString() ?? "",
        },
      };
      
      final response = await authCtrl.verifyIdentity(targetId, payload);
      
      if (response.status == true) {
        FancyNotification.show(
          context,
          "Vérification envoyée avec succès !",
          type: NotificationType.success,
        );
        Navigator.pop(context, true);
      } else {
        // L'erreur est déjà gérée dans le controller, mais on affiche un message ici aussi
        final errorMsg = response.errorMsg ?? "Erreur lors de la vérification";
        FancyNotification.show(
          context,
          errorMsg,
          type: NotificationType.error,
        );
      } 
      
    } catch (e) {
      print("Erreur vérification: $e");
      FancyNotification.show(context, "Erreur: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Vérification d'identité", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction, // Les erreurs disparaissent dès que le champ est valide
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pour publier une annonce, nous devons valider votre identité. Veuillez compléter les informations suivantes.",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              SizedBox(height: 24),

              // Photo de Profil Section
              Center(
                child: GestureDetector(
                  onTap: () => _pickImage(true),
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          image: _imageProfile != null 
                              ? DecorationImage(image: FileImage(_imageProfile!), fit: BoxFit.cover)
                              : null,
                          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5), width: 2),
                        ),
                        child: _imageProfile == null 
                            ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),
              Center(child: Text("Photo de profil", style: TextStyle(fontWeight: FontWeight.w600))),
              
              SizedBox(height: 30),
              
              _buildSectionTitle("Informations"),
              SizedBox(height: 16),
              _buildTextField(
                controller: _addressController,
                label: "Adresse complète",
                icon: Icons.location_on_outlined,
              ),
              
              SizedBox(height: 24),
              _buildSectionTitle("Document d'Identité"),
              SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedCardType,
                decoration: _inputDecoration("Type de pièce", Icons.credit_card),
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                ),
                dropdownColor: Colors.white,
                items: ["Passeport", "Permis de conduire", "Carte d'électeur"]
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type,
                            style: TextStyle(
                              color: Colors.black87,
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCardType = val),
                 validator: (val) => val == null ? "Veuillez sélectionner le type de pièce" : null,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _cardNumberController,
                label: "Numéro de la pièce",
                icon: Icons.numbers,
                validator: (val) => val == null || val.isEmpty ? "Veuillez entrer le numéro de la pièce" : null,
              ),
              
              SizedBox(height: 24),
              Text("Photos du document (Caméra obligatoire)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              SizedBox(height: 8),
              
              // Pour le passeport, seul le recto est requis
              // Pour les autres types, recto et verso sont requis
              Row(
                children: [
                  Expanded(child: _buildImagePicker(true)), // Recto (toujours requis)
                  if (_selectedCardType != 'Passeport') ...[
                    SizedBox(width: 16),
                    Expanded(child: _buildImagePicker(false)), // Verso (pas requis pour passeport)
                  ],
                ],
              ),
              
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isLoading 
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("Soumettre la vérification", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              
              // Ajouter un espace pour la barre de navigation système
              SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryBlue,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(
        color: Colors.black87,
        fontSize: 16,
      ),
      decoration: _inputDecoration(label, icon),
      validator: validator ?? (value) => value == null || value.isEmpty ? "Ce champ est requis" : null,
    );
  }
  
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.black87),
      hintStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryBlue, width: 2)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _buildImagePicker(bool isFront) {
    // isFront=true => Recto, isFront=false => Verso
    // But we reuse the same helper logic for simplicity
    return _buildCardPicker(isFront);
  }
  
  Widget _buildCardPicker(bool isFront) {
    final image = isFront ? _imageFront : _imageBack;
    final label = isFront ? "Recto" : "Verso";
    
    return GestureDetector(
      onTap: () => _pickImage(false, isFront: isFront),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
          image: image != null ? DecorationImage(image: FileImage(image), fit: BoxFit.cover) : null,
        ),
        child: image == null 
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, color: Colors.grey[400], size: 30),
                  SizedBox(height: 8),
                  Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                ],
              )
            : null,
      ),
    );
  }
}
