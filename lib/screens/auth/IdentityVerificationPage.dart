import 'dart:convert';
import 'dart:io';

import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:flutter/foundation.dart' show consolidateHttpClientResponseBytes;
import 'package:casa/utils/AppColors.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/decertification_access_guard.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/requetes.dart';
import 'package:casa/utils/crashlytics_api.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../camera/SelfieCameraScreen.dart';
import '../camera/DocumentCameraScreen.dart';

class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({Key? key}) : super(key: key);

  @override
  State<IdentityVerificationPage> createState() => _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage> {
  final _formKeyInfo = GlobalKey<FormState>();
  final _formKeyDoc = GlobalKey<FormState>();
  bool _completionPopScheduled = false;

  /// 0 = contexte et règles, 1 = coordonnées + photo de profil, 2 = pièce d’identité et envoi.
  int _kycStep = 0;

  static const Color _kycBorder = Color(0xFFEFF3F4);
  static const Color _kycMuted = Color(0xFF536471);
  static const Color _kycPageBg = Color(0xFFF8FAFC);
  static const List<String> _kycStepLabels = [
    'Contexte',
    'Coordonnées',
    'Pièce d’identité',
  ];

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

  Future<File> _persistPickedImage(File source, {required String prefix}) async {
    // Certains fichiers (caméra / cache) peuvent disparaître entre la capture et l'envoi en prod.
    // On copie donc dans un dossier persistant propre à l'app.
    final supportDir = await getApplicationSupportDirectory();
    final kycDir = Directory('${supportDir.path}/kyc_images');
    if (!await kycDir.exists()) {
      await kycDir.create(recursive: true);
    }

    // Préserver l’extension si possible.
    final name = source.path.split('/').last;
    final dot = name.lastIndexOf('.');
    final ext = (dot >= 0 && dot < name.length - 1) ? name.substring(dot) : '.jpg';
    final dst = File('${kycDir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext');
    try {
      return await source.copy(dst.path);
    } catch (_) {
      // Fallback: si copy échoue (permissions, etc.), garder le fichier initial.
      return source;
    }
  }

  Future<String?> _ensureFileExists(File? f, String label) async {
    if (f == null) return "Fichier manquant ($label).";
    try {
      if (!await f.exists()) {
        return "La photo $label n'est plus disponible. Reprenez-la puis réessayez.";
      }
    } catch (_) {
      return "Impossible d'accéder à la photo $label. Reprenez-la puis réessayez.";
    }
    return null;
  }

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

      // Sauvegarder dans support dir pour éviter les suppressions de cache en prod.
      final supportDir = await getApplicationSupportDirectory();
      final kycDir = Directory('${supportDir.path}/kyc_images');
      if (!await kycDir.exists()) {
        await kycDir.create(recursive: true);
      }
      final tmp = File('${kycDir.path}/profile_prefill_${DateTime.now().millisecondsSinceEpoch}.jpg');
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

  /// Un seul retour arrière fiable après envoi réussi (navigateur courant, puis racine si besoin).
  void _safePopWithVerificationResult([Object? result = true]) {
    if (!mounted || _completionPopScheduled) return;
    _completionPopScheduled = true;
    try {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop(result);
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    try {
      final root = Navigator.of(context, rootNavigator: true);
      if (root.canPop()) {
        root.pop(result);
      }
    } catch (_) {}
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
          final persisted = await _persistPickedImage(File(imagePath!), prefix: 'profile');
          if (!mounted) return;
          setState(() {
            _imageProfile = persisted;
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
        final persisted = await _persistPickedImage(
          File(imagePath!),
          prefix: isFront ? 'card_front' : 'card_back',
        );
        if (!mounted) return;
        setState(() {
          if (isFront) {
            _imageFront = persisted;
          } else {
            _imageBack = persisted;
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

    final infoOk = _formKeyInfo.currentState?.validate() ?? false;
    final docOk = _formKeyDoc.currentState?.validate() ?? false;
    if (!infoOk || !docOk) {
      setState(() {});
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
      final missingProfile = await _ensureFileExists(_imageProfile, "de profil");
      if (missingProfile != null) {
        FancyNotification.show(context, missingProfile, isError: true);
        setState(() => _isLoading = false);
        return;
      }
      final missingFront = await _ensureFileExists(_imageFront, "recto");
      if (missingFront != null) {
        FancyNotification.show(context, missingFront, isError: true);
        setState(() => _isLoading = false);
        return;
      }
      if (_selectedCardTypeId != 2) {
        final missingBack = await _ensureFileExists(_imageBack, "verso");
        if (missingBack != null) {
          FancyNotification.show(context, missingBack, isError: true);
          setState(() => _isLoading = false);
          return;
        }
      }

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
        final uid = authCtrl.user.userId?.toString() ?? '';
        if (uid.isNotEmpty) {
          try {
            (authCtrl.stockage ?? GetStorage()).write(
              '${StockageKeys.kycDocsSubmittedAtKey}_$uid',
              DateTime.now().millisecondsSinceEpoch,
            );
          } catch (_) {}
        }
        // Évite qu’un refresh membre déclenché juste après ré-ouvre tout de suite la décertification
        // alors que le serveur peut encore indiquer « non certifié » le temps du traitement.
        DecertificationAccessGuard.resetPresentationDebounce();

        await authCtrl.refreshMemberFromServer(force: true);

        if (!mounted) return;

        FancyNotification.show(
          context,
          "Demande envoyée. Vous serez informé après analyse de vos documents.",
          type: NotificationType.success,
        );

        await Future<void>.delayed(const Duration(milliseconds: 140));
        if (!mounted) return;
        _safePopWithVerificationResult(true);
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
      backgroundColor: _kycPageBg,
      appBar: AppBar(
        title: Text("Vérification d'identité", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            if (_kycStep == 0) {
              Navigator.pop(context);
            } else {
              setState(() => _kycStep--);
            }
          },
        ),
      ),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildKycStepProgress(),
              const SizedBox(height: 20),
              if (_kycStep == 0) _buildKycIntroStep(),
              if (_kycStep > 0) ...[
                Form(
                  key: _formKeyInfo,
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Offstage(
                    offstage: _kycStep != 1,
                    child: _buildKycCoordonneesStep(),
                  ),
                ),
                Form(
                  key: _formKeyDoc,
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Offstage(
                    offstage: _kycStep != 2,
                    child: _buildKycDocumentStep(isCardTypeSelected),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      // bottomNavigationBar: ...
    );
  }

  String _displayNameForVerification() {
    try {
      final auth = context.read<AuthentificationCtrl>();
      final fromUser = (auth.user.fullName ?? '').trim();
      if (fromUser.isNotEmpty) return fromUser;
      final un = (auth.user.username ?? '').trim();
      if (un.isNotEmpty) return un;

      final raw = auth.stockage?.read(StockageKeys.profileKey);
      if (raw is! Map) return '';

      final map = Map<String, dynamic>.from(raw);
      for (final key in ['fullName', 'full_name', 'fullname']) {
        final v = map[key]?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
      }
      final f = (map['firstName'] ?? map['first_name'])?.toString().trim() ?? '';
      final l = (map['lastName'] ?? map['last_name'])?.toString().trim() ?? '';
      final combined = '$f $l'.trim();
      if (combined.isNotEmpty) return combined;
      final u = map['username']?.toString().trim();
      return (u != null && u.isNotEmpty) ? u : '';
    } catch (_) {
      return '';
    }
  }

  Widget _buildIdentitySummaryCard() {
    final name = _displayNameForVerification();
    final hasName = name.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, size: 20, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'Nom sur votre compte',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _kycMuted,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasName ? name : 'Non renseigné pour l’instant',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: hasName ? Colors.black87 : _kycMuted,
            ),
          ),
          if (!hasName) ...[
            const SizedBox(height: 8),
            Text(
              'Le nom sur votre pièce d’identité devra correspondre à celui affiché sur votre profil une fois complété.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKycStepProgress() {
    final i = _kycStep.clamp(0, 2);
    final progress = (i + 1) / 3.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Étape ${i + 1} sur 3',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
                letterSpacing: 0.1,
              ),
            ),
            Text(
              _kycStepLabels[i],
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _kycMuted,
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
            color: AppColors.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildKycIntroBodyLine(String prefix, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              prefix,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: _kycMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKycIntroStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vérification d’identité',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'On confirme que c’est bien vous, pour la sécurité de CasaNayo et de tous les membres.',
          style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 22),
        Text(
          'Photo du document, vos infos de contact, puis envoi pour contrôle.',
          style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Expanded(child: _buildKycIntroMiniStep('1', 'Photo')),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 22),
              Expanded(child: _buildKycIntroMiniStep('2', 'Infos')),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 22),
              Expanded(child: _buildKycIntroMiniStep('3', 'Envoi')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Vous pouvez continuer tout de suite. Les règles détaillées sont ci‑dessous (facultatif).',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontStyle: FontStyle.italic,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                iconColor: AppColors.primaryBlue,
                collapsedIconColor: AppColors.primaryBlue,
                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                title: Text(
                  'Pourquoi on demande une pièce ?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Touchez ici pour lire',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                children: [
                  const SizedBox(height: 10),
                  _buildKycIntroBodyLine(
                    '1.',
                    'Vous nous envoyez vos documents pour que nous puissions les vérifier. '
                    'Si tout est correct, votre compte pourra être certifié (une marque de confiance sur votre profil).',
                  ),
                  _buildKycIntroBodyLine(
                    '2.',
                    'Nous regardons surtout trois choses : la photo est-elle nette et lisible ? '
                    'Les infos correspondent-elles à votre compte ? '
                    'Le document est-il bien au nom de la personne qui utilise l’application ?',
                  ),
                  _buildKycIntroBodyLine(
                    '3.',
                    'Si nous trouvons un problème grave , par exemple une photo floue, un document qui n’est pas le vôtre, ou des infos qui ne collent pas,  '
                    'nous pouvons bloquer ou fermer le compte le temps de tout vérifier, pour protéger les autres utilisateurs.',
                  ),
                  _buildKycIntroBodyLine(
                    '4.',
                    'Vos fichiers servent uniquement à cette vérification. Nous ne les mettons pas sur votre profil public et nous les gardons avec soin.',
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => setState(() => _kycStep = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Continuer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKycIntroMiniStep(String num, String label) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Text(
            num,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  void _goFromCoordToDoc() {
    _touchedFields['address'] = true;
    if (_isPhoneRequired) _touchedFields['phone'] = true;
    setState(() {});
    if (!(_formKeyInfo.currentState?.validate() ?? false)) {
      return;
    }
    if (_imageProfile == null) {
      FancyNotification.show(context, "Veuillez ajouter une photo de profil", isError: true);
      return;
    }
    setState(() => _kycStep = 2);
  }

  Widget _buildKycCoordonneesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vos coordonnées',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Le nom ci‑dessous vient de votre profil (lecture seule). Complétez avec une photo nette et votre adresse.',
          style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 18),
        _buildIdentitySummaryCard(),
        const SizedBox(height: 22),
        Center(
          child: GestureDetector(
            onTap: () => _pickImage(true),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    image: _imageProfile != null
                        ? DecorationImage(image: FileImage(_imageProfile!), fit: BoxFit.cover)
                        : null,
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: _imageProfile == null
                      ? Icon(Icons.person_rounded, size: 48, color: Colors.grey[400])
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Photo de profil',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Informations'),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _addressController,
          label: 'Adresse complète',
          icon: Icons.location_on_outlined,
          validator: (val) {
            if (!_touchedFields.containsKey('address') &&
                _formKeyInfo.currentState?.validate() != false) {
              return null;
            }
            return val == null || val.isEmpty ? 'Veuillez entrer votre adresse' : null;
          },
          onChanged: () {
            _touchedFields['address'] = true;
          },
        ),
        if (_isPhoneRequired) ...[
          const SizedBox(height: 16),
          _buildPhoneField(),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _kycStep = 0),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: _kycBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retour', style: TextStyle(fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _goFromCoordToDoc,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Continuer',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildKycDocumentStep(bool isCardTypeSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pièce d’identité',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sélectionnez le type de document, complétez les champs puis capturez les photos via la caméra (obligatoire pour la qualité).',
          style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 22),
        _isLoadingCards
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Chargement des types de cartes…',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : DropdownButtonFormField<int>(
                value: _selectedCardTypeId,
                decoration: _inputDecoration('Type de pièce', Icons.credit_card),
                style: const TextStyle(
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
                      style: const TextStyle(color: Colors.black87),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCardTypeId = val;
                    _selectedCardTypeDisplay = val != null
                        ? _getCardDisplayName(
                            _cardTypes.firstWhere((c) => c['typeCardId'] == val)['name'],
                            val,
                          )
                        : null;
                    _touchedFields['cardType'] = true;
                  });
                },
                validator: (val) {
                  if (!_touchedFields.containsKey('cardType') &&
                      _formKeyDoc.currentState?.validate() != false) {
                    return null;
                  }
                  return val == null ? 'Veuillez sélectionner le type de pièce' : null;
                },
              ),
        const SizedBox(height: 16),
        Opacity(
          opacity: isCardTypeSelected ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !isCardTypeSelected,
            child: _buildTextField(
              controller: _cardNumberController,
              label: 'Numéro de la pièce',
              icon: Icons.numbers,
              validator: (val) {
                if (!isCardTypeSelected) return null;
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
              'Veuillez d’abord sélectionner un type de pièce',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'Photos du document (caméra obligatoire)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: isCardTypeSelected ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !isCardTypeSelected,
            child: Row(
              children: [
                Expanded(child: _buildImagePicker(true)),
                if (_selectedCardTypeId != 2) ...[
                  const SizedBox(width: 16),
                  Expanded(child: _buildImagePicker(false)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: () => setState(() => _kycStep = 1),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black87,
            side: const BorderSide(color: _kycBorder),
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Étape précédente', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitVerification,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Soumettre la vérification',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Vos documents sont traités de manière confidentielle et ne sont pas diffusés publiquement.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
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
      style: const TextStyle(
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
          if (!_touchedFields.containsKey('phone') && _formKeyInfo.currentState?.validate() != false) {
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