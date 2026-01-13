import 'dart:convert';
import 'dart:io';

import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/utils/AppColors.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/requetes.dart';
import 'package:casa/utils/Constantes.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../camera/SelfieCameraScreen.dart';
import '../camera/DocumentCameraScreen.dart';

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
  int? _selectedCardTypeId; // ID du type de carte depuis l'API
  String? _selectedCardTypeDisplay; // Texte affiché ("Passeport", "Permis de conduire", "Carte d'électeur")
  File? _imageProfile; // Photo de profil
  File? _imageFront;
  File? _imageBack;
  bool _isLoading = false;
  bool _isLoadingCards = false;
  
  // Liste des types de cartes depuis l'API
  List<Map<String, dynamic>> _cardTypes = [];
  
  // Map pour suivre quels champs ont été touchés
  final Map<String, bool> _touchedFields = {};
  
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
      _loadCardTypes();
    });
  }

  Future<void> _loadCardTypes() async {
    setState(() => _isLoadingCards = true);
    try {
      final token = context.read<AuthentificationCtrl>().stockage?.read<String>(StockageKeys.tokenKey);
      final response = await getData(Endpoints.cards, token: token);
      
      if (response != null && response['data'] != null) {
        final List<dynamic> data = response['data'];
        _cardTypes = data.map((item) => {
          'typeCardId': item['typeCardId'],
          'name': item['name'],
        }).toList();
        
        // Filtrer pour exclure "Autres" (typeCardId: 4)
        _cardTypes = _cardTypes.where((card) => card['typeCardId'] != 4).toList();
        
        print("✅ Types de cartes chargés: $_cardTypes");
      }
    } catch (e) {
      print("❌ Erreur chargement types de cartes: $e");
      // Fallback sur les types par défaut
      _cardTypes = [
        {'typeCardId': 2, 'name': 'Visa'}, // Afficher comme "Passeport"
        {'typeCardId': 3, 'name': 'Permis'}, // Afficher comme "Permis de conduire"
        {'typeCardId': 1, 'name': "Carte d'électeur"},
      ];
    } finally {
      if (mounted) {
        setState(() => _isLoadingCards = false);
      }
    }
  }

  String _getCardDisplayName(String apiName, int typeCardId) {
    // Mapper les noms de l'API vers les noms d'affichage
    if (typeCardId == 2) return "Passeport"; // Visa -> Passeport
    if (typeCardId == 3) return "Permis de conduire"; // Permis -> Permis de conduire
    if (typeCardId == 1) return "Carte d'électeur";
    return apiName;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cardNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isProfile, {bool isFront = true}) async {
    try {
      String? imagePath;
      
      if (isProfile) {
        // Enforce Selfie Camera only - use await to get result safely
        imagePath = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => SelfieCameraScreen(
              onImageCaptured: (path) {
                // Callback still needed for compatibility, but we'll use the returned value
              },
            ),
          ),
        );
        
        // Only update state if widget is still mounted and we have a valid path
        if (mounted && imagePath != null && imagePath.isNotEmpty) {
          setState(() {
            _imageProfile = File(imagePath!);
          });
        }
        return;
      }

      // For ID cards, use Custom Document Camera to prevent crashes with native ImagePicker
      final label = isFront ? "Recto" : "Verso";
      
      imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentCameraScreen(
            label: label,
            onImageCaptured: (path) {
              // Callback still needed for compatibility, but we'll use the returned value
            },
          ),
        ),
      );
      
      // Only update state if widget is still mounted and we have a valid path
      if (mounted && imagePath != null && imagePath.isNotEmpty) {
        setState(() {
          if (isFront) {
            _imageFront = File(imagePath!);
          } else {
            _imageBack = File(imagePath!);
          }
        });
      }
      
    } catch (e) {
      print("❌ Erreur choix image: $e");
      if (mounted) {
        FancyNotification.show(context, "Impossible d'accéder à la caméra", isError: true);
      }
    }
  }

  Future<void> _submitVerification() async {
    // Fermer le clavier
    FocusScope.of(context).unfocus();

    // Marquer tous les champs comme touchés lors de la soumission
    _touchedFields['address'] = true;
    _touchedFields['cardType'] = true;
    // _touchedFields['cardNumber'] = true; // Numéro facultatif

    if (!_formKey.currentState!.validate()) {
      setState(() {}); // Forcer la mise à jour pour afficher les erreurs
      return;
    }
    
    if (_imageProfile == null) {
       FancyNotification.show(context, "Veuillez ajouter une photo de profil", isError: true);
       return;
    }

    if (_selectedCardTypeId == null) {
      FancyNotification.show(context, "Veuillez sélectionner le type de pièce d'identité", isError: true);
      return;
    }
    
    if (_imageFront == null) {
      FancyNotification.show(context, "Veuillez ajouter la photo recto de votre pièce d'identité", isError: true);
      return;
    }
    
    // Pour le passeport (typeCardId = 2, car Visa -> Passeport), le verso n'est pas requis
    // Pour les autres types, le verso est requis
    if (_selectedCardTypeId != 2 && _imageBack == null) {
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

      // 1. D'abord, uploader l'image de profil
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

      // 2. Ensuite, envoyer la vérification d'identité
      String frontBase64 = base64Encode(await _imageFront!.readAsBytes());
      String backBase64 = _imageBack != null 
          ? base64Encode(await _imageBack!.readAsBytes())
          : "";
      
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

      final userData = authCtrl.stockage?.read(StockageKeys.userKey) ?? {};
      
      final payload = {
        "lastName": lastName,
        "firstName": firstName,
        "address": _addressController.text,
        "cardFront": frontBase64,
        "cardBack": backBase64,
        "typeCardId": _selectedCardTypeId,
        "parrainId": 0,
        "numberCard": _cardNumberController.text, // Peut être vide
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
        final errorMsg = response.errorMsg ?? "Erreur lors de la vérification";
        FancyNotification.show(
          context,
          _sanitizeError(errorMsg),
          type: NotificationType.error,
        );
      } 
      
    } catch (e) {
      print("Erreur vérification: $e");
      FancyNotification.show(context, "Une erreur est survenue. Veuillez réessayer.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Vérifier si un type de carte est sélectionné pour activer les champs dépendants
    final bool isCardTypeSelected = _selectedCardTypeId != null;

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
          autovalidateMode: AutovalidateMode.disabled,
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
                validator: (val) {
                  if (!_touchedFields.containsKey('address') && _formKey.currentState?.validate() != false) {
                    return null;
                  }
                  return val == null || val.isEmpty ? "Veuillez entrer votre adresse" : null;
                },
                onChanged: () {
                  _touchedFields['address'] = true;
                },
              ),
              
              SizedBox(height: 24),
              _buildSectionTitle("Document d'Identité"),
              SizedBox(height: 16),
              
              _isLoadingCards
                  ? Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 16),
                          Text("Chargement des types de cartes...", style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : DropdownButtonFormField<int>(
                      value: _selectedCardTypeId,
                      decoration: _inputDecoration("Type de pièce", Icons.credit_card),
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                      dropdownColor: Colors.white,
                      items: _cardTypes.map((card) {
                        final typeCardId = card['typeCardId'] as int;
                        final displayName = _getCardDisplayName(card['name'] as String, typeCardId);
                        return DropdownMenuItem<int>(
                          value: typeCardId,
                          child: Text(
                            displayName,
                            style: TextStyle(
                              color: Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCardTypeId = val;
                          _selectedCardTypeDisplay = val != null 
                              ? _getCardDisplayName(
                                  _cardTypes.firstWhere((c) => c['typeCardId'] == val)['name'],
                                  val
                                )
                              : null;
                          _touchedFields['cardType'] = true;
                        });
                      },
                      validator: (val) {
                        if (!_touchedFields.containsKey('cardType') && _formKey.currentState?.validate() != false) {
                          return null;
                        }
                        return val == null ? "Veuillez sélectionner le type de pièce" : null;
                      },
                    ),
              SizedBox(height: 16),
              
              // Numéro de la pièce (Désactivé tant que le type n'est pas choisi)
              Opacity(
                opacity: isCardTypeSelected ? 1.0 : 0.5,
                child: AbsorbPointer(
                  absorbing: !isCardTypeSelected,
                  child: _buildTextField(
                    controller: _cardNumberController,
                    label: "Numéro de la pièce (Optionnel)",
                    icon: Icons.numbers,
                    validator: null, // Rendu optionnel
                    onChanged: () {
                      _touchedFields['cardNumber'] = true;
                    },
                  ),
                ),
              ),
              if (!isCardTypeSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    "Veuillez d'abord sélectionner un type de pièce",
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              
              SizedBox(height: 24),
              Text("Photos du document (Caméra obligatoire)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              SizedBox(height: 8),
              
              Opacity(
                opacity: isCardTypeSelected ? 1.0 : 0.5,
                child: AbsorbPointer(
                  absorbing: !isCardTypeSelected,
                  child: Row(
                    children: [
                      Expanded(child: _buildImagePicker(true)), // Recto
                      if (_selectedCardTypeId != 2) ...[
                        SizedBox(width: 16),
                        Expanded(child: _buildImagePicker(false)), // Verso
                      ],
                    ],
                  ),
                ),
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
              SizedBox(height: 8),
              Center(
                child: Text(
                  "Vos documents sont sécurisés et ne seront jamais partagés.",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
      // bottomNavigationBar: ...
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
    VoidCallback? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(
        color: Colors.black87,
        fontSize: 16,
      ),
      decoration: _inputDecoration(label, icon),
      validator: validator, // Le validator est maintenant passé correctement (peut être null)
      onChanged: (value) {
        // _touchedFields[label] = true; // Fix: label change dynamiquement avec "(Optionnel)"
        if (onChanged != null) onChanged();
      },
      onTap: () {
        // _touchedFields[label] = true;
      },
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
  String _sanitizeError(String? error) {
    if (error == null || error.isEmpty) return "Une erreur est survenue. Veuillez réessayer.";
    final lower = error.toLowerCase();
    
    if (lower.contains("internal server error") || 
        lower.contains("exception") || 
        lower.contains("status")) {
      return "Une erreur est survenue. Veuillez réessayer.";
    }
    return error; 
  }
}
