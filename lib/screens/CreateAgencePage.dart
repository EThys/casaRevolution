import 'dart:convert';
import 'dart:io';

import 'package:casa/controllers/AgenceController.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:get_storage/get_storage.dart';
import 'package:casa/utils/StockageKeys.dart';

class CreateAgencePage extends StatefulWidget {
  @override
  _CreateAgencePageState createState() => _CreateAgencePageState();
}

class _CreateAgencePageState extends State<CreateAgencePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _addressController = TextEditingController();
  
  File? _logoImage;
  final _picker = ImagePicker();
  bool _isLoading = false;

  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFF64B5F6);

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _logoImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      FancyNotification.show(context, "Erreur lors de la sélection de l'image");
    }
  }

  Future<String?> _imageToBase64(File image) async {
    try {
      final bytes = await image.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }



  Future<void> _submitForm() async {
    // 1. Dismiss keyboard and prevent double clicks
    FocusScope.of(context).unfocus();
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_logoImage == null) {
      FancyNotification.show(context, "Veuillez sélectionner un logo pour l'agence");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (!await NetworkUtils.checkInternetConnectivity()) {
      FancyNotification.show(context, "Pas de connexion internet");
      setState(() { _isLoading = false; });
      return;
    }

    try {
      // Convert image to base64
      final logoBase64 = await _imageToBase64(_logoImage!);
      if (logoBase64 == null) {
        throw Exception("Erreur lors du traitement de l'image");
      }
      
      // Retrieve userId from Storage
      final storage = GetStorage();
      final userData = storage.read(StockageKeys.userKey);
      int userId = 0;
      if (userData != null) {
          // Essayer différentes clés possibles pour l'ID utilisateur
          userId = userData['user']?['userId'] ?? userData['userId'] ?? userData['id'] ?? 0;
      }

      final payload = {
        "userId": userId, 
        "name": _nameController.text.trim(),
        "description": _descriptionController.text.trim(),
        "phone1": _phone1Controller.text.trim(),
        "phone2": _phone2Controller.text.trim(),
        "address": _addressController.text.trim(),
        "logo": logoBase64
      };

      final agenceCtrl = Provider.of<AgenceController>(context, listen: false);
      final response = await agenceCtrl.createAgence(payload);

      if (response.status == true) {
        String message = "Agence créée avec succès. Vous pouvez maintenant publier votre annonce.";
        if (response.data != null && response.data is Map && response.data.containsKey('message')) {
            message = response.data['message'];
        }
        FancyNotification.show(context, message, isError: false);
        // Retour avec un résultat pour informer la page précédente
        Navigator.pop(context, true);
      } else {
        // Gestion plus précise des erreurs
        String errorMsg = response.errorMsg ?? "Erreur lors de la création";
        if (response.data != null && response.data['errors'] != null) {
           errorMsg = response.data['errors'].toString(); 
        }
        FancyNotification.show(context, _sanitizeError(errorMsg), isError: true);
      }
    } catch (e) {
      print("Erreur création agence: $e");
      String friendlyError = "Une erreur est survenue. Veuillez vérifier votre connexion.";
      if (e.toString().contains("Internal Server Error")) {
         friendlyError = "Le serveur rencontre des difficultés momentanées. Veuillez réessayer plus tard.";
      }
      FancyNotification.show(context, friendlyError, isError: true);
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
      appBar: AppBar(
        title: Text(
          "Créer une agence",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
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
              // Friendly Text
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: primaryColor, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Pour publier des sites touristiques ou des lieux de vacances, vous devez d'abord avoir une agence enregistrée.",
                        style: TextStyle(
                            color: Colors.black87, 
                            fontSize: 14,
                            height: 1.4
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _buildLogoUpload(),
              SizedBox(height: 24),
              _buildTextField(
                controller: _nameController,
                label: "Nom de l'agence",
                icon: Icons.business,
                validator: (value) =>
                    value!.isEmpty ? "Le nom est obligatoire" : null,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: "Description",
                icon: Icons.description,
                maxLines: 3,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _phone1Controller,
                label: "Téléphone 1",
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value!.isEmpty ? "Le téléphone est obligatoire" : null,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _phone2Controller,
                label: "Téléphone 2 (Optionnel)",
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _addressController,
                label: "Adresse",
                icon: Icons.location_on,
                validator: (value) =>
                    value!.isEmpty ? "L'adresse est obligatoire" : null,
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Enregistrer l'agence",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoUpload() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
            border: Border.all(color: primaryColor, width: 2),
            image: _logoImage != null
                ? DecorationImage(
                    image: FileImage(_logoImage!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _logoImage == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 40, color: Colors.grey[400]),
                    SizedBox(height: 4),
                    Text(
                      "Logo",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
  String _sanitizeError(String? error) {
    if (error == null || error.isEmpty) return "Une erreur est survenue lors de la création.";
    final lower = error.toLowerCase();
    
    // Technical errors
    if (lower.contains("internal server error") || 
        lower.contains("exception") || 
        lower.contains("status")) {
      return "Une erreur est survenue. Veuillez réessayer.";
    }
    // Mask if map structure
    if (error.startsWith("{") && error.contains("}")) {
       return "Veuillez vérifier les informations saisies.";
    }
    return error; 
  }
}
