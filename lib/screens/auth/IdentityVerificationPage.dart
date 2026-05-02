import 'dart:convert';
import 'dart:io';

import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:flutter/foundation.dart' show consolidateHttpClientResponseBytes;
import 'package:casa/utils/AppColors.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/requetes.dart';
import 'package:casa/utils/crashlytics_api.dart';
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
  final _phoneController = TextEditingController();

  // State
  int? _selectedCardTypeId; // ID du type de carte depuis l'API
  String? _selectedCardTypeDisplay; // Texte affiché ("Passeport", "Permis de conduire", "Carte d'électeur")
  File? _imageProfile; // Photo de profil
  File? _imageFront;
  File? _imageBack;
  bool _isLoading = false;
  bool _isLoadingCards = false;
  bool _isPhoneRequired = false;

  // Liste des types de cartes depuis l'API
  List<Map<String, dynamic>> _cardTypes = [];

  // Map pour suivre quels champs ont été touchés
  final Map<String, bool> _touchedFields = {};

  // Phone Logic from LoginScreen
  String _selectedCountryCode = '+243'; // RDC par défaut
  final Map<String, String> _countryFlags = {
    '+243': '🇨🇩', // RDC
    '+1': '🇺🇸', // USA
    '+33': '🇫🇷', // France
    '+32': '🇧🇪', // Belgique
    '+242': '🇨🇬', // Congo Brazzaville
    '+41': '🇨🇭', // Suisse
    '+44': '🇬🇧', // UK
    '+49': '🇩🇪', // Allemagne
    '+20': '🇪🇬', // Égypte
    '+27': '🇿🇦', // Afrique du Sud
    '+212': '🇲🇦', // Maroc
    '+213': '🇩🇿', // Algérie
    '+216': '🇹🇳', // Tunisie
    '+221': '🇸🇳', // Sénégal
    '+225': '🇨🇮', // Côte d'Ivoire
    '+237': '🇨🇲', // Cameroun
    '+241': '🇬🇦', // Gabon
    '+229': '🇧🇯', // Bénin
    '+228': '🇹🇬', // Togo
    '+223': '🇲🇱', // Mali
    '+224': '🇬🇳', // Guinée
    '+227': '🇳🇪', // Niger
    '+226': '🇧🇫', // Burkina Faso
    '+257': '🇧🇮', // Burundi
    '+250': '🇷🇼', // Rwanda
    '+256': '🇺🇬', // Ouganda
    '+254': '🇰🇪', // Kenya
    '+255': '🇹🇿', // Tanzanie
    '+244': '🇦🇴', // Angola
    '+234': '🇳🇬', // Nigeria
    '+233': '🇬🇭', // Ghana
  };

  final ImagePicker _picker = ImagePicker();
  bool _profilePhotoIsExisting = false;

  Future<void> _prefillProfilePhotoIfAvailable() async {
    if (_imageProfile != null) return;
    try {
      final authCtrl = context.read<AuthentificationCtrl>();
      final storage = authCtrl.stockage;

      // 1) Fichier local utilisé par ProfilePage (upload précédent).
      final localPath = storage?.read('user_image_path')?.toString();
      if (localPath != null && localPath.isNotEmpty) {
        final f = File(localPath);
        if (await f.exists()) {
          if (!mounted) return;
          setState(() {
            _imageProfile = f;
            _profilePhotoIsExisting = true;
          });
          return;
        }
      }

      // 2) URL stockée dans le profil (profile.image / profile.images).
      final profileData = storage?.read(StockageKeys.profileKey);
      final url = (profileData is Map)
          ? (profileData['image']?.toString() ?? profileData['images']?.toString())
          : null;
      if (url == null || url.trim().isEmpty) return;
      final u = url.trim();
      if (!u.startsWith('http')) return;

      final http = HttpClient();
      final req = await http.getUrl(Uri.parse(u));
      final resp = await req.close();
      if (resp.statusCode < 200 || resp.statusCode >= 300) return;
      final bytes = await consolidateHttpClientResponseBytes(resp);

      // Sauvegarder en temp pour réutiliser FileImage + base64Encode(readAsBytes()).
      final tmpDir = Directory.systemTemp;
      final tmp = File('${tmpDir.path}/casanayo_profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tmp.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _imageProfile = tmp;
        _profilePhotoIsExisting = true;
      });
    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'IdentityVerificationPage',
        error: e,
        stackTrace: st,
        reason: 'prefill_profile_photo_exception',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec les infos utilisateur si disponibles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authCtrl = context.read<AuthentificationCtrl>();

      // Check phone logic
      final userData = authCtrl.stockage?.read(StockageKeys.userKey);
      final storedPhone = userData?['phone']?.toString();

      if (storedPhone == null || storedPhone.isEmpty || storedPhone == "null") {
        setState(() {
          _isPhoneRequired = true;
        });
      }

      if (authCtrl.user.city != null) {
        _addressController.text = authCtrl.user.city ?? "";
      }
      // Pré-remplir infos déjà connues (si l’utilisateur avait déjà commencé / terminé une vérification).
      final profileData = authCtrl.stockage?.read(StockageKeys.profileKey);
      if (profileData is Map) {
        final existingType = profileData['typeCardId'] ?? profileData['type_card_id'];
        final existingNumber = profileData['numberCard'] ?? profileData['number_card'];
        final tid = existingType is int ? existingType : int.tryParse(existingType?.toString() ?? '');
        if (tid != null && tid > 0) {
          _selectedCardTypeId = tid;
          try {
            final match = _cardTypes.firstWhere((c) => c['typeCardId'] == tid, orElse: () => {});
            final name = match is Map ? (match['name']?.toString() ?? '') : '';
            if (name.isNotEmpty) {
              _selectedCardTypeDisplay = _getCardDisplayName(name, tid);
            }
          } catch (_) {}
        }
        final n = existingNumber?.toString() ?? '';
        if (n.trim().isNotEmpty) {
          _cardNumberController.text = n.trim();
        }
      }
      _prefillProfilePhotoIfAvailable();
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
        
        // Convert and Filter: Keep only IDs 1, 2, 3. Exclude 4 (Autres).
        _cardTypes = data
            .map((item) => {
                  'typeCardId': item['typeCardId'],
                  'name': item['name'],
                })
            .where((card) => card['typeCardId'] != 4)
            .toList();

        print("✅ Types de cartes sélectionnés (1,2,3): $_cardTypes");
      }
    } catch (e) {
      print("❌ Erreur chargement types de cartes API: $e");
      // Fallback conforme aux types demandés
      _cardTypes = [
        {'typeCardId': 1, 'name': "Carte d'électeur"},
        {'typeCardId': 2, 'name': 'Visa'}, // Sera affiché comme Passeport
        {'typeCardId': 3, 'name': 'Permis'}, // Sera affiché comme Permis de conduire
      ];
    } finally {
      if (mounted) {
        setState(() => _isLoadingCards = false);
      }
    }
  }

  String _getCardDisplayName(String apiName, int typeCardId) {
    // Mapper les noms de l'API vers les noms d'affichage souhaités
    switch (typeCardId) {
      case 1:
        return "Carte d'électeur";
      case 2:
        return "Passeport"; // Visa -> Passeport
      case 3:
        return "Permis de conduire"; // Permis -> Permis de conduire
      default:
        return apiName;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cardNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isProfile, {bool isFront = true}) async {
    try {
      String? imagePath;

      if (isProfile) {
        // Bottomsheet identique à ProfilePage (design original).
        final hasExisting = _imageProfile != null;
        final ImageSource? source = await showModalBottomSheet<ImageSource>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) {
            Widget actionTile({
              required IconData icon,
              required String title,
              required String subtitle,
              required VoidCallback onTap,
            }) {
              return InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: AppColors.primaryBlue, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.account_circle_rounded, color: AppColors.primaryBlue),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Photo de profil',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Fermer', style: TextStyle(color: Colors.grey.shade700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (hasExisting) ...[
                      actionTile(
                        icon: Icons.fullscreen_rounded,
                        title: 'Aperçu en plein écran',
                        subtitle: 'Voir votre photo actuelle.',
                        onTap: () {
                          final f = _imageProfile;
                          Navigator.pop(context);
                          if (f == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                backgroundColor: Colors.black,
                                appBar: AppBar(
                                  backgroundColor: Colors.black,
                                  elevation: 0,
                                  leading: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),
                                body: Center(child: Image.file(f, fit: BoxFit.contain)),
                              ),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                    ],
                    actionTile(
                      icon: Icons.camera_alt_rounded,
                      title: 'Prendre une photo',
                      subtitle: 'Utiliser la caméra.',
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                    Divider(height: 1, color: Colors.grey.shade200),
                    actionTile(
                      icon: Icons.photo_library_rounded,
                      title: 'Choisir depuis la galerie',
                      subtitle: 'Sélectionner une image existante.',
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );

        if (source == null) return;

        if (source == ImageSource.camera) {
          imagePath = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => SelfieCameraScreen(
                onImageCaptured: (path) {},
              ),
            ),
          );
        } else {
          final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
          imagePath = file?.path;
        }

        if (mounted && imagePath != null && imagePath.isNotEmpty) {
          setState(() {
            _imageProfile = File(imagePath!);
            _profilePhotoIsExisting = false; // l'utilisateur a choisi une nouvelle photo
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
    if (_isPhoneRequired) _touchedFields['phone'] = true;
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
      FancyNotification.show(
        context,
        "Ajoutez aussi le verso de votre pièce d’identité pour continuer.",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    if (!await NetworkUtils.checkInternetConnectivity()) {
      setState(() => _isLoading = false);
      FancyNotification.show(
        context,
        "Connexion internet indisponible pour le moment. Réessayez dès que le réseau revient.",
        isError: true,
      );
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

      // 1. Photo de profil: si elle existe déjà, ne pas re-uploader.
      if (!_profilePhotoIsExisting) {
        final profileBase64 = base64Encode(await _imageProfile!.readAsBytes());
        final profileImageResponse = await authCtrl.updateProfilePicture(targetId, profileBase64);

        if (!profileImageResponse.status) {
          reportApiFailureToCrashlytics(
            'IdentityVerificationPage',
            response: profileImageResponse,
            reason: 'profile_picture_upload',
          );
          FancyNotification.show(
            context,
            profileImageResponse.errorMsg ??
                "La photo de profil n’a pas pu être envoyée. Vérifiez votre connexion et réessayez.",
            type: NotificationType.error,
          );
          setState(() => _isLoading = false);
          return;
        }
        print("✅ Image de profil uploadée avec succès");
      } else {
        print("✅ Photo de profil déjà existante: upload ignoré");
      }

      // 2. Ensuite, envoyer la vérification d'identité
      String frontBase64 = base64Encode(await _imageFront!.readAsBytes());
      String backBase64 = _imageBack != null
          ? base64Encode(await _imageBack!.readAsBytes())
          : "";

      // L'utilisateur demande de laisser le prénom et le nom vides lors de la vérification
      // pour ne pas écraser les valeurs déjà présentes dans la BDD (ex: Loïc).
      String firstName = "";
      String lastName = "";
      int parrainId = 0;

      try {
        if (profileData != null && profileData is Map) {
          // On garde parrainId car il est nécessaire pour la cohérence,
          // mais on laisse firstName et lastName vides selon la demande.
          parrainId = profileData['parrain_id'] ?? profileData['parrainId'] ?? 0;
        }
      } catch (e) {
        print("Erreur lecture profile keys: $e");
      }

      final userData = authCtrl.stockage?.read(StockageKeys.userKey) ?? {};

      final cardNumber = _cardNumberController.text.trim().isEmpty
          ? "string"
          : _cardNumberController.text.trim();

      final payload = {
        "lastName": lastName,
        "firstName": firstName,
        "address": _addressController.text.trim(),
        "cardFront": frontBase64,
        "cardBack": backBase64,
        "typeCardId": _selectedCardTypeId, // Envoi de l'ID correct sélectionné
        "type_card_id": _selectedCardTypeId, // Fallback snake_case
        "parrainId": parrainId, 
        "parrain_id": parrainId, // Fallback snake_case
        // Le backend attend bien `numberCard` (String). On envoie une valeur même si vide.
        "numberCard": cardNumber, 
        "number_card": cardNumber, // Fallback snake_case
        "user": {
          "email": (userData['email']?.toString() ?? "").isEmpty ? "string" : userData['email']?.toString() ?? "",
          "phone": _isPhoneRequired ? _formatPhoneNumberForSubmit() : (userData['phone']?.toString() ?? ""),
          "city": userData['city']?.toString() ?? "",
          "country": userData['country']?.toString() ?? "",
        },
      };

      print("📤 Payload vérification d'identité: ${jsonEncode({
        "lastName": payload["lastName"],
        "firstName": payload["firstName"],
        "typeCardId": payload["typeCardId"],
        "numberCard": payload["numberCard"],
        "user": payload["user"]
      })} (images non incluses dans ce log)");

      final response = await authCtrl.verifyIdentity(targetId, payload);

      if (response.status == true) {
        FancyNotification.show(
          context,
          "Votre demande de vérification a bien été envoyée.",
          type: NotificationType.success,
        );
        Navigator.pop(context, true);
      } else {
        reportApiFailureToCrashlytics(
          'IdentityVerificationPage',
          response: response,
          reason: 'verify_identity',
        );
        final errorMsg = response.errorMsg ??
            "La vérification n’a pas abouti. Vérifiez les informations et réessayez.";
        FancyNotification.show(
          context,
          _sanitizeError(errorMsg),
          type: NotificationType.error,
        );
      }

    } catch (e, st) {
      reportApiFailureToCrashlytics(
        'IdentityVerificationPage',
        error: e,
        stackTrace: st,
        reason: 'verify_identity_exception',
      );
      print("Erreur vérification: $e");
      FancyNotification.show(
        context,
        "Quelque chose s’est mal passé de notre côté. Patientez un instant et réessayez.",
        isError: true,
      );
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

              if (_isPhoneRequired) ...[
                SizedBox(height: 16),
                _buildPhoneField(),
              ],

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
                    label: "Numéro de la pièce",
                    icon: Icons.numbers,
                    validator: (val) {
                      if (!isCardTypeSelected) return null;
                      final s = (val ?? '').trim();
                      if (s.isEmpty) {
                        return "Veuillez entrer le numéro indiqué sur la pièce";
                      }
                      return null;
                    },
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
    if (error == null || error.isEmpty) {
      return "Impossible de finaliser l’étape pour l’instant. Réessayez dans quelques instants.";
    }
    final lower = error.toLowerCase();

    if (lower.contains("internal server error") ||
        lower.contains("exception") ||
        lower.contains("status")) {
      return "Le service est temporairement occupé. Merci de réessayer dans un moment.";
    }
    return error;
  }

  // --- Phone Utilities adapted from LoginScreen ---

  Widget _buildPhoneField() {
    return TextFormField(
        controller: _phoneController,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: 'Numéro de téléphone',
          labelStyle: TextStyle(color: Colors.black87),
          hintText: '810000000',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: _buildCountryCodeDropdown(),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryBlue, width: 2)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: (val) {
          if (!_isPhoneRequired) return null;
          if (!_touchedFields.containsKey('phone') && _formKey.currentState?.validate() != false) {
            return null;
          }
          if (val == null || val.isEmpty) return "Veuillez entrer votre numéro";

          final cleaned = val.replaceAll(RegExp(r'[^\d]'), '');

          if (_selectedCountryCode == '+243') {
            if (cleaned.length != 9) return "Le numéro RDC doit avoir 9 chiffres";
            if (!RegExp(r'^[89]').hasMatch(cleaned)) return "Le numéro doit commencer par 8 ou 9";
          } else {
            if (cleaned.length < 8) return "Numéro invalide";
          }
          return null;
        },
        onChanged: (value) {
          _touchedFields['phone'] = true;
          // Clean leading zero
          String cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
          if (cleaned.startsWith('0') && cleaned.length > 1) {
            cleaned = cleaned.substring(1);
            _phoneController.value = TextEditingValue(
              text: cleaned,
              selection: TextSelection.collapsed(offset: cleaned.length),
            );
          }
        }
    );
  }

  Widget _buildCountryCodeDropdown() {
    return Container(
      width: 110,
      margin: EdgeInsets.only(right: 8),
      padding: EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[300]!))
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCountryCode,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.primaryBlue, size: 20),
          style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
          items: _countryFlags.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.value, style: TextStyle(fontSize: 14)),
                  SizedBox(width: 4),
                  Text(entry.key, style: TextStyle(fontSize: 13)),
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

  String _formatPhoneNumberForSubmit() {
    String raw = _phoneController.text.trim();
    String cleaned = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    // Si l'utilisateur n'a pas déjà mis l'indicatif (ce qui est probable vu l'UI)
    if (!cleaned.startsWith(_selectedCountryCode.replaceAll('+', ''))) {
      return "$_selectedCountryCode$cleaned";
    }
    return "+$cleaned";
  }
}