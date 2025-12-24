import 'dart:convert';
import 'dart:io';

import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/utils/AppColors.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

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
      // Pour les cartes (pas Profil), on force la caméra
      final source = isProfile ? ImageSource.gallery : ImageSource.camera;
      
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Optimisation
        maxWidth: 1024,
      );
      
      if (photo != null) {
        setState(() {
          if (isProfile) {
            _imageProfile = File(photo.path);
          } else if (isFront) {
            _imageFront = File(photo.path);
          } else {
            _imageBack = File(photo.path);
          }
        });
      }
    } catch (e) {
      print("Erreur choix image: $e");
      FancyNotification.show(context, "Impossible d'accéder à la caméra ou la galerie", isError: true);
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_imageProfile == null) {
       FancyNotification.show(context, "Veuillez ajouter une photo de profil", isError: true);
       return;
    }

    if (_imageFront == null || _imageBack == null) {
      FancyNotification.show(context, "Veuillez ajouter les photos recto et verso de votre pièce d'identité", isError: true);
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

      // Conversion des images en Base64
      String profileBase64 = base64Encode(await _imageProfile!.readAsBytes());
      String frontBase64 = base64Encode(await _imageFront!.readAsBytes());
      String backBase64 = base64Encode(await _imageBack!.readAsBytes());
      
      // Mapping du type de carte vers un ID
      int typeCardId = 0;
      switch (_selectedCardType) {
        case 'Passeport': typeCardId = 1; break;
        case 'Permis de conduire': typeCardId = 2; break;
        case "Carte d'électeur": typeCardId = 3; break;
        default: typeCardId = 1;
      }
      
      // Récupération des noms depuis le profil existant (ou vide si manquant)
      // Le user a dit "ne demande pas le prenom et le nom", donc on utilise ce qu'on a déjà.
      String firstName = authCtrl.user.username ?? "";
      String lastName = ""; // Si on n'a pas le nom séparé, on laisse vide ou on gère autrement
      
      // Essai de splitter le username si besoin, ou juste envoyer ce qu'on a
      // Comme c'est un PUT, l'idéal serait de ne pas écraser avec du vide si c'est déjà là,
      // mais le payload demande ces champs string.

      final payload = {
        "lastName": lastName, // Revoir si on peut récupérer ça du user model mieux
        "firstName": firstName,
        "address": _addressController.text,
        "images": profileBase64, 
        "cardFront": frontBase64,
        "cardBack": backBase64,
        "typeCardId": typeCardId,
        "parrainId": 0,
        "numberCard": _cardNumberController.text,
      };

      await authCtrl.verifyIdentity(authCtrl.user.userId.toString(), payload);
      
      FancyNotification.show(context, "Vérification envoyée avec succès !", isError: false);
      Navigator.pop(context, true); 
      
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
                items: ["Passeport", "Permis de conduire", "Carte d'électeur"]
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
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
              
              Row(
                children: [
                  Expanded(child: _buildImagePicker(true)), // Recto
                  SizedBox(width: 16),
                  Expanded(child: _buildImagePicker(false)), // Verso
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
      decoration: _inputDecoration(label, icon),
      validator: validator ?? (value) => value == null || value.isEmpty ? "Ce champ est requis" : null,
    );
  }
  
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
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
