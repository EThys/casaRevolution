import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:share_plus/share_plus.dart';
import 'package:casa/utils/casanayo_share_copy.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';

import '../utils/Routes.dart';
import '../controllers/AuthentificationCtrl.dart';
import 'package:casa/controllers/NotificationController.dart';
import 'camera/SelfieCameraScreen.dart';
import 'auth/IdentityVerificationPage.dart';
import '../utils/StockageKeys.dart';
import '../utils/database/FavoriteDatabaseHelper.dart';
import '../utils/database/ReservationDatabaseHelper.dart';
import '../utils/database/DatabaseHelper.dart';
import '../utils/database/PropertyDatabaseHelper.dart';
import '../utils/database/PrestationDatabaseHelper.dart';
import '../utils/TerrainDatabaseHelper.dart';
import '../utils/DraftHelper.dart';
import '../controllers/ThemeController.dart';
import '../controllers/RegisterBailleurCtrl.dart';
import '../controllers/RegisterLocataireCtrl.dart';
import '../controllers/RegisterCommissionnaireCtrl.dart';
import '../controllers/RegisterPlombierCtrl.dart';
import '../controllers/RegisterElectricienCtrl.dart';
import '../controllers/RegisterSalubriteCtrl.dart';
import '../controllers/RegisterChauffeurCtrl.dart';
import '../controllers/RegisterMajordomeCtrl.dart';
import '../controllers/RegisterPeintreCtrl.dart';
import '../controllers/RegisterCarreleurCtrl.dart';
import '../controllers/RegisterMenuisierCtrl.dart';
import '../controllers/RegisterFrigoristeCtrl.dart';
import '../controllers/RegisterAjusteurCtrl.dart';
import '../controllers/RegisterArchitecteCtrl.dart';
import '../controllers/RegisterDemenagementCtrl.dart';
import '../utils/FancyNotification.dart';
import '../utils/requetes.dart';
import 'package:provider/provider.dart';
import 'HomePage.dart';
import 'AppSettingsPage.dart';
import '../controllers/PropertyCtrl.dart';
import '../controllers/ServiceController.dart';
import '../controllers/AgenceController.dart';
import '../widgets/ModernCustomDialog.dart';
import '../Apps/MonApllication.dart';


class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();

  // Static method to be called from anywhere (e.g. HomePage)
  static Future<int> updatePublicationCount(BuildContext context, {bool force = false}) async {
    try {
      final storage = GetStorage();

      // Check for cache validity (TTL of 5 minutes)
      if (!force) {
        final lastUpdateTime = storage.read('publication_count_last_update');
        final cachedCount = storage.read('published_properties_count');

        if (lastUpdateTime != null && cachedCount != null) {
          final lastUpdate = DateTime.fromMillisecondsSinceEpoch(lastUpdateTime);
          if (DateTime.now().difference(lastUpdate).inMinutes < 5) {
            print("📦 [ProfilePage] Utilisant le cache (TTL < 5min): $cachedCount");
            return int.tryParse(cachedCount.toString()) ?? 0;
          }
        }
      }

      final userData = storage.read(StockageKeys.userKey);
      dynamic userId;
      if (userData != null && userData is Map) {
        userId = userData['user']?['userId'] ?? userData['userId'];
      }

      if (userId == null) return 0;

      int total = 0;
      final results = await Future.wait([
        (() async {
          try {
            final propertyCtrl = Provider.of<PropertyController>(context, listen: false);
            final myProps = await propertyCtrl.getMyProperties();
            return myProps.length;
          } catch (e) { return 0; }
        })(),
        (() async {
          try {
            final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
            final services = await serviceCtrl.getMyPrestations();
            return services.length;
          } catch (e) { return 0; }
        })(),
        (() async {
          try {
            final agenceCtrl = Provider.of<AgenceController>(context, listen: false);
            await agenceCtrl.fetchAgencesByUser(userId);
            int agencyTotal = 0;
            if (agenceCtrl.agences.isNotEmpty) {
              for (var agency in agenceCtrl.agences) {
                if (agency.sites != null) agencyTotal += agency.sites!.length;
              }
            }
            return agencyTotal;
          } catch (e) { return 0; }
        })(),
      ]);

      total = results.reduce((a, b) => a + b);

      // Cache the count and the time
      storage.write('published_properties_count', total.toString());
      storage.write('publication_count_last_update', DateTime.now().millisecondsSinceEpoch);
      print("✅ [ProfilePage] Compteur mis à jour depuis API: $total");

      return total;
    } catch (e) {
      print("Error in updatePublicationCount: $e");
      return 0;
    }
  }
}

class _ProfilePageState extends State<ProfilePage> {
  final GetStorage storage = GetStorage();
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF2D3748);
  final Color _lightColor = Color(0xFFF7FAFC);
  final Color _greyColor = Color(0xFF718096);
  final Color _successColor = Color(0xFF48BB78);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFE2E8F0);
  final Color _warningColor = Color(0xFFED8936);

  File? _imageFile;
  String? _profileImageUrl; // URL de l'image de profil depuis l'API
  final ImagePicker _picker = ImagePicker();
  bool _isDeleting = false; // Pour l'effet de suppression impactant
  bool _isLoading = false;
  double _profileCompletion = 0.0;
  final RefreshController _profileRefreshController = RefreshController();
  String _publicationsCount = '0'; // Local state for dynamic count

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _calculateProfileCompletion();

    // Fetch dynamic counts after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPublicationsCount();
    });
  }

  void _loadSavedData() async {
    // D'abord, essayer de charger depuis l'URL stockée dans le profil (priorité)
    final profileData = storage.read(StockageKeys.profileKey);
    String? imageUrl;

    if (profileData != null && profileData is Map) {
      imageUrl = profileData['image']?.toString() ?? profileData['images']?.toString();
    }

    // Si on a une URL, la stocker pour l'affichage
    if (imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('/')) {
      // C'est une URL, on l'utilisera avec CachedNetworkImage
      setState(() {
        _profileImageUrl = imageUrl;
        _imageFile = null; // Pas de fichier local si on a une URL
      });
    } else {
      // Fallback: charger depuis le chemin local
      final imagePath = storage.read('user_image_path');
      if (imagePath != null && File(imagePath).existsSync()) {
        setState(() {
          _imageFile = File(imagePath);
          _profileImageUrl = null;
        });
      }
    }

    // Charger le compteur de publications mis en cache pour un affichage immédiat
    final cachedCount = storage.read('published_properties_count');
    if (cachedCount != null) {
      setState(() {
        _publicationsCount = cachedCount.toString();
      });
    }
  }

  void _calculateProfileCompletion() {
    int completedFields = 0;
    int totalFields = 6; // Photo, Address, Card Type, Card Number, Card Front, Card Back

    final profileData = storage.read(StockageKeys.profileKey) ?? {};
    final userData = storage.read(StockageKeys.userKey) ?? {};

    // 1. Profile Photo (check file, URL, or profile data)
    bool hasPhoto = _imageFile != null ||
        (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) ||
        (profileData['image'] != null && profileData['image'].toString().isNotEmpty);
    if (hasPhoto) completedFields++;

    // 2. Address
    if (profileData['address']?.toString().isNotEmpty == true ||
        userData['address']?.toString().isNotEmpty == true) completedFields++;

    // 3. Card Type
    if (profileData['cardType']?.toString().isNotEmpty == true ||
        profileData['typeCardId'] != null) completedFields++;

    // 4. Card Number
    if (profileData['numberCard']?.toString().isNotEmpty == true) completedFields++;

    // 5. Card Front
    if (profileData['cardFront']?.toString().isNotEmpty == true) completedFields++;

    // 6. Card Back
    if (profileData['cardBack']?.toString().isNotEmpty == true) completedFields++;

    // Si l'utilisateur est certifié ou l'a été auparavant, on considère que c'est 100%
    // conformément à la demande de ne pas faire baisser la complétion
    final String userId = userData['user']?['userId']?.toString() ?? userData['userId']?.toString() ?? "";
    bool wasCertified = storage.read<bool>('${StockageKeys.wasCertifiedKey}_$userId') ?? false;
    
    if (userData['isCertified'] == true || userData['isVerified'] == true || wasCertified) {
      completedFields = totalFields;
    }

    setState(() {
      _profileCompletion = completedFields / totalFields;
    });
  }

  // ... (keep getters)

  void _navigateToEditProfile() async {
    // Si le profil n'est pas "complet" (vérifié), on dirige vers la vérification d'identité
    // qui fait office de "Complétion de profil"
    final userData = storage.read(StockageKeys.userKey);
    final isCertified = userData?['isCertified'] == true;

    if (!isCertified) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => IdentityVerificationPage()),
      );

      if (result == true) {
        _loadSavedData();
        _calculateProfileCompletion();
      }
    } else {
      // Si déjà certifié, on ouvre l'édition standard (Bio, etc.)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditProfilePage(
            accountType: accountType,
            profileId: profileId,
            onProfileUpdated: () {
              setState(() {
                _loadSavedData();
                _calculateProfileCompletion();
              });
            },
          ),
        ),
      );
    }
  }

  bool get isLoggedIn {
    final token = storage.read(StockageKeys.tokenKey);
    return token != null && token.isNotEmpty;
  }

  String get safeUsername {
    final userData = storage.read(StockageKeys.userKey);
    final profileData = storage.read(StockageKeys.profileKey);

    // PRIORITÉ 1: fullName
    final fullName = profileData?['fullname']?.toString() ?? profileData?['fullName']?.toString() ??
        userData?['fullname']?.toString() ?? userData?['fullName']?.toString();

    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    // PRIORITÉ 2: username
    return userData?['username']?.toString() ??
        profileData?['username']?.toString() ??
        'Bio'; // Or Visiteur
  }

  String get safeEmail {
    final userData = storage.read(StockageKeys.userKey);
    return userData?['email']?.toString() ?? 'Non connecté';
  }

  String get safePhone {
    final userData = storage.read(StockageKeys.userKey);
    final raw = userData?['phone']?.toString() ?? '';
    final v = raw.trim();
    if (v.isEmpty || v.toLowerCase() == 'null') return '';
    return v;
  }

  String get safeAddress {
    final profileData = storage.read(StockageKeys.profileKey);
    return profileData?['address']?.toString() ?? '';
  }

  String get bio {
    final profileData = storage.read(StockageKeys.profileKey);
    return profileData?['bio']?.toString() ??
        'Ajoutez une bio pour personnaliser votre profil';
  }

  String get firstname {
    final profileData = storage.read(StockageKeys.profileKey);
    return profileData?['firstname']?.toString() ?? '';
  }

  String get lastname {
    final profileData = storage.read(StockageKeys.profileKey);
    return profileData?['lastname']?.toString() ?? '';
  }

  String get fullname {
    final profileData = storage.read(StockageKeys.profileKey);
    return profileData?['fullname']?.toString() ?? safeUsername;
  }

  String get accountType {
    final userData = storage.read(StockageKeys.userKey);
    if (userData != null && userData['typeAccount'] != null) {
      return userData['typeAccount']['name']?.toString() ?? 'Non spécifié';
    }
    return 'Non spécifié';
  }

  String get displayAccountTypes {
    final accounts = storage.read('user_accounts');
    if (accounts != null && accounts is List && accounts.isNotEmpty) {
      final List<String> roleNames = [];
      for (var acc in accounts) {
        if (acc is Map) {
          String? specName = acc['name']?.toString();
          // Si on a un nom spécifique (ex: bailleur), on l'utilise directement
          // Sinon on utilise le nom du type (ex: Propriétaire)
          if (specName != null && specName.isNotEmpty) {
            roleNames.add(specName[0].toUpperCase() + specName.substring(1).toLowerCase());
          } else if (acc['typeAccount']?['name'] != null) {
            roleNames.add(acc['typeAccount']['name']);
          }
        }
      }
      if (roleNames.isNotEmpty) {
        // Suppression des doublons potentiels et jointure
        return roleNames.toSet().join(' & ');
      }
    }
    return accountType;
  }

  Map<String, dynamic>? get profileData {
    return storage.read(StockageKeys.profileKey);
  }

  int? get profileId {
    // Utiliser l'ID du profil (profile.id) depuis le stockage (priorité)
    final profileData = storage.read(StockageKeys.profileKey);
    if (profileData != null && profileData is Map) {
      final id = profileData['id'];
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
    }

    // Fallback: utiliser userId si profile.id n'est pas disponible
    final userData = storage.read(StockageKeys.userKey);
    if (userData != null) {
      final userId = userData['user']?['userId'] ?? userData['userId'];
      if (userId is int) return userId;
      if (userId is String) return int.tryParse(userId);
    }

    return null;
  }

  String get publishedProperties {
    return _publicationsCount;
  }



  @override
  void dispose() {
    _profileRefreshController.dispose();
    super.dispose();
  }

  void _endProfileRefresh({required bool success}) {
    if (!mounted) return;
    final status = _profileRefreshController.headerStatus;
    final pulling = status == RefreshStatus.refreshing || status == RefreshStatus.canRefresh;
    if (!pulling) return;
    if (success) {
      _profileRefreshController.refreshCompleted();
    } else {
      _profileRefreshController.refreshFailed();
    }
  }

  Future<void> _handleProfileRefresh() async {
    try {
      final auth = context.read<AuthentificationCtrl>();
      if (auth.token.isNotEmpty) {
        await auth.refreshMemberFromServer(force: true);
      }
      _loadSavedData();
      _calculateProfileCompletion();
      await _fetchPublicationsCount();
      _endProfileRefresh(success: true);
    } catch (_) {
      _endProfileRefresh(success: false);
    }
  }

  Future<void> _fetchPublicationsCount() async {
    final count = await ProfilePage.updatePublicationCount(context);
    if (mounted) {
      setState(() {
        _publicationsCount = count.toString();
      });
    }
  }



  String get referralsCount {
    return storage.read('referrals_count')?.toString() ?? '0';
  }


  bool _isUploadingPhoto = false;

  Future<File> _persistPickedImage(File source, {required String prefix}) async {
    final supportDir = await getApplicationSupportDirectory();
    final imgDir = Directory('${supportDir.path}/persisted_images');
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }
    final name = source.path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    final ext = (dot >= 0 && dot < name.length - 1) ? name.substring(dot) : '.jpg';
    final dst = File('${imgDir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext');
    try {
      return await source.copy(dst.path);
    } catch (_) {
      return source;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    String? path;

    if (source == ImageSource.camera) {
      // Custom Selfie Camera
      path = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => SelfieCameraScreen(
            onImageCaptured: (path) {},
          ),
        ),
      );
    } else {
      // Pick from Gallery
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Compresser un peu pour l'upload
      );
      path = file?.path;
    }

    if (path == null || path.isEmpty) return;
    // Copier l'image hors cache Android pour éviter PathNotFoundException en prod.
    final persisted = await _persistPickedImage(File(path), prefix: 'profile');
    final String imagePath = persisted.path;

    setState(() {
      _imageFile = File(imagePath);
      _isUploadingPhoto = true; // Animation de chargement sur l'avatar uniquement
    });
    await storage.write('user_image_path', imagePath);
    _calculateProfileCompletion();

    // S'il y a un profileId, uploader l'image via l'endpoint séparé
    final authCtrl = context.read<AuthentificationCtrl>();

    // Priorité à l'ID du profil
    final profileData = storage.read(StockageKeys.profileKey);
    int? pid;
    if (profileData != null && profileData is Map) {
      pid = profileData['id'];
    }

    final targetId = pid?.toString() ?? authCtrl.user.userId?.toString();

    if (targetId != null) {
      try {
        final f = File(imagePath);
        if (!await f.exists()) {
          throw Exception("Image introuvable. Reprenez la photo puis réessayez.");
        }
        final bytes = await f.readAsBytes();
        final base64Image = base64Encode(bytes);

        final response = await authCtrl.updateProfilePicture(targetId, base64Image);

        final responseMsg = response.data?['message']?.toString().toLowerCase() ?? "";
        final isMsgSuccess = responseMsg.contains("avec") && responseMsg.contains("succès");

        if (response.status || isMsgSuccess) {
          // Récupérer l'URL de l'image depuis la réponse
          final imageUrl = response.data?['image'] ?? response.data?['images'] ?? response.data?['person']?['images'];

          if (imageUrl != null && imageUrl.toString().isNotEmpty) {
            setState(() {
              _profileImageUrl = imageUrl.toString();
            });
          }

          FancyNotification.show(
            context,
            response.data?['message'] ?? "Photo de profil mise à jour !",
            isError: false,
            type: NotificationType.success, // Forcer la couleur verte
          );

          // Forcer le rechargement pour le drawer et autres écrans
          authCtrl.notifyListeners();
        } else {
          FancyNotification.show(
            context,
            response.errorMsg ??
                "La photo n’a pas pu être mise à jour. Réessayez ou choisissez une autre image.",
            isError: true,
            type: NotificationType.error,
          );
        }
      } catch (e) {
        print("Erreur upload photo: $e");
        FancyNotification.show(
          context,
          "L’envoi de la photo a échoué. Vérifiez la connexion et réessayez.",
          isError: true,
          type: NotificationType.error,
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingPhoto = false;
          });
        }
      }
    } else {
      setState(() => _isUploadingPhoto = false);
    }
  }

  void _shareApp() {
    Share.share(
      CasanayoShareCopy.appInvitationMessage(),
      subject: CasanayoShareCopy.shareAppSubject,
    );
  }

  void _showProfileOptions() {
    // Vérifier si on a au moins une image (locale ou distante)
    final localPath = storage.read('user_image_path');
    final hasLocal = localPath != null && File(localPath).existsSync();
    final hasRemote = _profileImageUrl != null && _profileImageUrl!.isNotEmpty;

    showModalBottomSheet(
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
                      color: _primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: _primaryColor, size: 22),
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
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.account_circle_rounded, color: _primaryColor),
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
                if (hasLocal || hasRemote) ...[
                  actionTile(
                    icon: Icons.fullscreen_rounded,
                    title: 'Aperçu en plein écran',
                    subtitle: 'Voir votre photo actuelle.',
                    onTap: () {
                      Navigator.pop(context);
                      _viewFullScreenPhoto(hasLocal ? localPath : _profileImageUrl!);
                    },
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                ],
                actionTile(
                  icon: Icons.camera_alt_rounded,
                  title: 'Prendre une photo',
                  subtitle: 'Utiliser la caméra.',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                actionTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Choisir depuis la galerie',
                  subtitle: 'Sélectionner une image existante.',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewFullScreenPhoto(String pathOrUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: PhotoView(
              imageProvider: pathOrUrl.startsWith('http')
                  ? CachedNetworkImageProvider(pathOrUrl)
                  : FileImage(File(pathOrUrl)) as ImageProvider,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2.0,
              heroAttributes: const PhotoViewHeroAttributes(tag: "profile_image"),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCompletionCard() {
    if (!isLoggedIn || _profileCompletion >= 1.0) return SizedBox.shrink();

    return GestureDetector(
      onTap: _navigateToEditProfile,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_add_alt_1, color: _warningColor, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complétez votre profil',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _darkColor,
                        ),
                      ),
                      Text(
                        '${(_profileCompletion * 100).toInt()}% complété',
                        style: TextStyle(
                          fontSize: 12,
                          color: _greyColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, size: 16, color: _greyColor),
                  onPressed: _navigateToEditProfile,
                ),
              ],
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: _profileCompletion,
              backgroundColor: _borderColor,
              color: _primaryColor,
              borderRadius: BorderRadius.circular(10),
              minHeight: 6,
            ),
            SizedBox(height: 8),
            Text(
              _getCompletionMessage(),
              style: TextStyle(
                fontSize: 12,
                color: _greyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCompletionMessage() {
    final userData = storage.read('user_data') ?? {};
    List<String> missingFields = [];

    if (userData['phone']?.toString().isEmpty == true) missingFields.add('téléphone');
    if (userData['address']?.toString().isEmpty == true) missingFields.add('adresse');
    if (userData['bio']?.toString().isEmpty == true) missingFields.add('bio');
    if (_imageFile == null) missingFields.add('photo de profil');

    if (missingFields.isEmpty) return 'Votre profil est complet !';

    return 'Ajoutez : ${missingFields.join(', ')}';
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.only(top: 40, bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_primaryColor, _secondaryColor],
        ),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
          ),
          SizedBox(height: 5),
          GestureDetector(
            onTap: _showProfileOptions,
            child: Hero(
              tag: "profile_image",
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _cardColor, width: 3),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipOval(
                          child: Builder(
                              builder: (context) {
                                final localImagePath = storage.read('user_image_path');
                                final localFile = (localImagePath != null) ? File(localImagePath) : null;

                                if (localFile != null && localFile.existsSync()) {
                                  return Image.file(localFile, fit: BoxFit.cover, width: 100, height: 100);
                                }

                                if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
                                  return CachedNetworkImage(
                                    imageUrl: _profileImageUrl!,
                                    fit: BoxFit.cover,
                                    width: 100, height: 100,
                                    placeholder: (context, url) => Container(
                                      color: Colors.white.withOpacity(0.2),
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.white.withOpacity(0.2),
                                      child: Icon(Icons.person, size: 50, color: _cardColor),
                                    ),
                                  );
                                }

                                return Container(
                                  color: Colors.white.withOpacity(0.2),
                                  child: Icon(Icons.person, size: 50, color: _cardColor),
                                );
                              }
                          ),
                        ),
                        if (_isUploadingPhoto)
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.4),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: _cardColor, width: 2),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: _cardColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            safeUsername,
            style: TextStyle(
              color: _cardColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          // Badge du type de compte
          if (isLoggedIn)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _cardColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _cardColor.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_outlined, size: 16, color: _cardColor),
                  SizedBox(width: 6),
                  Text(
                    displayAccountTypes,
                    style: TextStyle(
                      color: _cardColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 16),
        ],
      ),
    );
  }


  Widget _buildStatsCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Stat des Publications (Améliorée et cliquable)
          _buildStatItem(
            value: _publicationsCount,
            label: 'Publications',
            icon: Icons.auto_awesome_motion_rounded,
            color: _primaryColor,
            isClickable: true,
            onTap: () => Navigator.pushNamed(context, Routes.myPropertiesRoute),
          ),

          _buildStatItem(
            value: referralsCount,
            label: 'Parrainages',
            icon: Icons.people_alt_rounded,
            color: _secondaryColor,
          ),

          _buildStatItem(
            value: '${(_profileCompletion * 100).toInt()}%',
            label: 'Profil',
            icon: Icons.verified_user_rounded,
            color: _successColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    bool isClickable = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, color: color, size: 26),
                  ),
                ),
                if (isClickable)
                  Positioned(
                    // Éviter que le badge sorte de la zone cliquable (sinon on a l'impression
                    // qu'il faut "2 clics" quand on tape sur le coin).
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.open_in_new_rounded, size: 10, color: color),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _darkColor,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _greyColor,
                letterSpacing: 0.2,
              ),
            ),
            if (isClickable)
              Container(
                margin: EdgeInsets.only(top: 4),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'GÉRER',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Nom complet',
            value: safeUsername,
          ),
          Divider(height: 24, color: _borderColor),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: safeEmail,
          ),
          Divider(height: 24, color: _borderColor),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Téléphone',
            value: safePhone.isNotEmpty ? safePhone : 'Non renseigné',
            isComplete: safePhone.isNotEmpty,
            onTap: safePhone.isNotEmpty ? () => _makePhoneCall(safePhone) : null,
          ),
          Divider(height: 24, color: _borderColor),
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Adresse',
            value: safeAddress.isNotEmpty ? safeAddress : 'Non renseignée',
            isComplete: safeAddress.isNotEmpty,
          ),
          if (isLoggedIn) ...[
            Divider(height: 24, color: _borderColor),
            _buildInfoRow(
              icon: Icons.badge_outlined,
              label: 'Type de compte',
              value: displayAccountTypes,
              isComplete: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isComplete = true,
    VoidCallback? onTap,
  }) {
    final clickable = onTap != null;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isComplete ? _primaryColor.withOpacity(0.1) : _warningColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
              icon,
              color: isComplete ? _primaryColor : _warningColor,
              size: 20
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: _greyColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isComplete ? _darkColor : _warningColor,
                ),
              ),
            ],
          ),
        ),
        if (!isComplete)
          Icon(
            Icons.info_outline,
            color: _warningColor,
            size: 16,
          )
        else if (clickable)
          Icon(
            Icons.chevron_right_rounded,
            color: _greyColor.withOpacity(0.7),
            size: 18,
          ),
      ],
    );

    if (!clickable) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: row,
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final v = phoneNumber.trim();
    if (v.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: v);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildAuthOptions() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          if (!isLoggedIn) ...[
            _buildAuthButton(
              text: 'Se connecter',
              onPressed: () {
                Navigator.pushNamed(context, Routes.loginRoute);
              },
              isPrimary: true,
              icon: Icons.login_rounded,
            ),
            SizedBox(height: 12),
            _buildAuthButton(
              text: 'Créer un compte',
              onPressed: () {
                Navigator.pushNamed(context, Routes.registerRoute);
              },
              isPrimary: false,
              icon: Icons.person_add_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuthButton({
    required String text,
    required VoidCallback onPressed,
    required bool isPrimary,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      child: isPrimary
          ? ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          shadowColor: _primaryColor.withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      )
          : OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          side: BorderSide(color: _primaryColor, width: 1.5),
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsMenu() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            'PARAMÈTRES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white54 : _greyColor,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingMenuItem(
                icon: Icons.settings_rounded,
                iconColor: _primaryColor,
                bgColor: _primaryColor.withOpacity(0.10),
                title: 'Paramètres',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AppSettingsPage()),
                  );
                },
                isDarkMode: isDarkMode,
              ),
              Divider(height: 1, indent: 60, endIndent: 20, color: _borderColor),
              /*
              // Mode sombre (désactivé temporairement)
              Consumer<ThemeController>(
                builder: (context, themeController, child) {
                  final isDark = themeController.isDarkMode;
                  return ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: _primaryColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Mode sombre',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : _darkColor,
                      ),
                    ),
                    trailing: Switch.adaptive(
                      value: isDark,
                      activeColor: _primaryColor,
                      onChanged: (value) {
                        themeController.toggleTheme();
                      },
                    ),
                  );
                },
              ),
              Divider(height: 1, indent: 60, endIndent: 20, color: _borderColor),
              */

              if (isLoggedIn) ...[
                Consumer<AuthentificationCtrl>(
                  builder: (context, auth, _) {
                    final premium = auth.user.isPremium == true;
                    return _buildSettingMenuItem(
                      icon: premium
                          ? Icons.receipt_long_rounded
                          : Icons.workspace_premium_rounded,
                      iconColor: _primaryColor,
                      bgColor: _primaryColor.withOpacity(0.10),
                      title: premium
                          ? 'Historique des paiements'
                          : 'Abonnement',
                      onTap: () => Navigator.pushNamed(
                        context,
                        premium
                            ? Routes.paymentHistoryRoute
                            : Routes.subscriptionPaymentRoute,
                      ),
                      isDarkMode: isDarkMode,
                    );
                  },
                ),
                Divider(height: 1, indent: 60, endIndent: 20, color: _borderColor),
              ],

              // Partager l'application
              _buildSettingMenuItem(
                icon: Icons.share_rounded,
                iconColor: _primaryColor,
                bgColor: _primaryColor.withOpacity(0.10),
                title: "Partager l'application",
                onTap: _shareApp,
                isDarkMode: isDarkMode,
              ),

              if (isLoggedIn) ...[
                Divider(height: 1, indent: 60, endIndent: 20, color: _borderColor),
                // Déconnexion
                _buildSettingMenuItem(
                  icon: Icons.logout_rounded,
                  iconColor: _primaryColor,
                  bgColor: _primaryColor.withOpacity(0.10),
                  title: 'Déconnexion',
                  onTap: _confirmLogout,
                  isDarkMode: isDarkMode,
                ),
              ],
            ],
          ),
        ),

        if (isLoggedIn) ...[
          SizedBox(height: 24),
          // Zone Danger (Suppression de compte)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? _primaryColor.withOpacity(0.08)
                  : _primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primaryColor.withOpacity(0.16)),
            ),
            child: _buildSettingMenuItem(
              icon: Icons.delete_forever_rounded,
              iconColor: _primaryColor,
              bgColor: _primaryColor.withOpacity(0.10),
              title: 'Supprimer mon compte définitivement',
              onTap: _showDeleteAccountConfirmationDialog,
              isDarkMode: isDarkMode,
              textColor: isDarkMode ? Colors.white : _darkColor,
              hideChevron: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSettingMenuItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required VoidCallback onTap,
    required bool isDarkMode,
    Color? textColor,
    bool hideChevron = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkMode ? iconColor.withOpacity(0.2) : bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textColor ?? (isDarkMode ? Colors.white : _darkColor),
        ),
      ),
      trailing: hideChevron ? null : Icon(Icons.chevron_right_rounded, size: 20, color: _greyColor),
    );
  }

  void _navigateToLogin() {
    Navigator.pushNamed(context, Routes.loginRoute);
  }

  void _navigateToSignup() {
    Navigator.pushNamed(context, Routes.registerRoute);
  }



  Future<void> _clearLocalAuthData() async {
    try {
      // 1. Supprimer les données d'authentification
      await storage.remove(StockageKeys.tokenKey);
      await storage.remove(StockageKeys.refreshTokenKey);
      await storage.remove(StockageKeys.userKey);
      await storage.remove(StockageKeys.userPreferenceKey);
      await storage.remove(StockageKeys.profileKey);

      // 2. Supprimer les données de cache du profil
      await storage.remove('user_image_path');
      await storage.remove('profile_image_path');
      await storage.remove('card_front_path');
      await storage.remove('card_back_path');
      await storage.remove('user_data');
      await storage.remove('user_accounts');
      await storage.remove('published_properties_count');
      await storage.remove('publication_count_last_update');
      await storage.remove('referrals_count');

      // Sécurité: supprimer toute variante éventuelle (clé suffixée/prefixée) de ces compteurs.
      try {
        final keys = storage.getKeys();
        for (final k in keys) {
          if (k.contains('published_properties_count') ||
              k.contains('publication_count_last_update') ||
              k.contains('referrals_count')) {
            await storage.remove(k);
          }
        }
      } catch (_) {}

      // 🛑 NETTOYAGE RADICAL DES BASES DE DONNÉES SQL (Sécurité totale)
      try {
        print("🧹 Début du nettoyage radical des bases SQL depuis ProfilePage...");

        // 1. Services & Prestations
        await PrestationDatabaseHelper.instance.clearAllPrestations();

        // 2. Propriétés générales & Catégories spéciales
        final db = DatabaseHelper.instance;
        await db.clearProperties();
        await db.clearCategory(DatabaseHelper.tableBureaux);
        await db.clearCategory(DatabaseHelper.tableFestives);
        await db.clearCategory(DatabaseHelper.tableFuneraires);

        // 3. Transactions & Requêtes
        await db.clearUserSolicitations();
        await db.clearHostSolicitations();
        await db.clearUserReservations();
        await db.clearHostReservations();
        await db.clearServiceRequests();

        // 4. Données utilisateur spécifiques
        await PropertyDatabaseHelper.instance.clearDatabase();
        await TerrainDatabaseHelper.instance.clearTerrains();

        print("✅ Nettoyage radical SQL terminé depuis ProfilePage");
      } catch (e) {
        print("⚠️ Erreur lors du nettoyage radical SQL: $e");
      }

      await FavoriteDatabaseHelper.instance.clearAllFavorites();
      await ReservationDatabaseHelper.instance.clearAllReservations();

      // 3. Supprimer TOUS les brouillons lors de la déconnexion
      try {
        await DraftHelper.clearAllDrafts();
        print("✅ Tous les brouillons supprimés");
      } catch (e) {
        print("⚠️ Erreur lors de la suppression des brouillons: $e");
      }

      // 4. Réinitialiser l'état local (uniquement si le widget est toujours monté)
      if (mounted) {
        setState(() {
          _imageFile = null;
          _profileCompletion = 0.0;
          _profileImageUrl = null;
        });
      }

      print("✅ Données d'authentification, cache du profil et bases de données locales supprimées");
    } catch (e) {
      print("❌ Erreur lors du nettoyage des données locales: $e");
      throw e;
    }
  }

  void _navigateToHomeAfterSessionReset() {
    MonApplication.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      Routes.bottomPageRoute,
      (route) => false,
    );
  }

  void _confirmLogout() {
    ModernCustomDialog.show(
      context,
      title: "Déconnexion",
      message: "Voulez-vous vraiment vous déconnecter ?",
      confirmText: "DÉCONNEXION",
      cancelText: "ANNULER",
      isDanger: true,
      popDialogOnSuccess: false,
      onConfirm: _performLogout,
      icon: Icons.logout_rounded,
    );
  }
/*
  void _confirmLogout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
...
*/

  Future<bool> _performLogout() async {
    // Note: On ne pop plus la dialog ici, elle reste affichée avec son loader
    // Elle sera détruite automatiquement par pushNamedAndRemoveUntil
    try {
      // 1. Nettoyer les données (storage + DB + cache écran)
      await _clearLocalAuthData();

      // 2. Réinitialiser l’état en mémoire des contrôleurs (Provider)
      // (sinon le UI peut continuer à afficher l'ancien user tant que l'app n'est pas redémarrée).
      try {
        context.read<NotificationController>().clearForLogout();
      } catch (e) {
        print("⚠️ [ProfilePage] clear notifications on logout failed: $e");
      }
      try {
        // Déconnexion locale: remet token/user à zéro + notifyListeners.
        await context.read<AuthentificationCtrl>().silentLogout();
      } catch (e) {
        print("⚠️ [ProfilePage] silentLogout failed: $e");
      }

      _navigateToHomeAfterSessionReset();
      return true;

    } catch (e) {
      print("❌ Erreur lors de la déconnexion: $e");

      // Même en cas d'erreur, essayer quand même de réinitialiser l'état en mémoire
      try {
        context.read<NotificationController>().clearForLogout();
      } catch (_) {}
      try {
        await context.read<AuthentificationCtrl>().silentLogout();
      } catch (_) {}

      _navigateToHomeAfterSessionReset();
      return true;
    }
  }

  void _showDeleteAccountConfirmationDialog() {
    ModernCustomDialog.show(
      context,
      title: 'Supprimer le compte ?',
      message: 'Cette action est irréversible. Toutes vos données seront définitivement effacées.',
      confirmText: 'OUI, SUPPRIMER DÉFINITIVEMENT',
      cancelText: 'GARDER MON COMPTE',
      isDanger: true,
      popDialogOnSuccess: false,
      onConfirm: _handleAccountDeletion,
    );
  }

  Future<bool> _handleAccountDeletion() async {
    setState(() => _isDeleting = true);

    try {
      // 1. Délai court pour "sentir" le début de l'action
      await Future.delayed(Duration(milliseconds: 500));

      final authCtrl = context.read<AuthentificationCtrl>();
      final response = await authCtrl.deleteAccount();

      if (response.status == true) {
        // 2. EFFET DE SUPPRESSION "PROLONGÉ ET RALENTI"
        // On attend la fin de l'animation majestueuse dans l'overlay
        await Future.delayed(Duration(milliseconds: 7000));

        _navigateToHomeAfterSessionReset();
        return true;
      } else {
        setState(() => _isDeleting = false);
        // Afficher un message plus utile si le backend envoie { message: ... }
        String message = response.errorMsg ?? "Échec de la suppression";
        try {
          final data = response.data;
          if (data is Map && data['message'] != null) {
            message = data['message'].toString();
          }
        } catch (_) {}
        print("❌ [ProfilePage] deleteAccount failed — httpStatus=${response.httpStatus}, errorMsg=${response.errorMsg}, data=${response.data}");
        FancyNotification.show(context, message);
        return false;
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      print("❌ [ProfilePage] Exception deleteAccount: $e");
      FancyNotification.show(context, "Une erreur est survenue");
      return false;
    }
  }

  Widget _buildDeletionOverlay() {
    if (!_isDeleting) return SizedBox.shrink();

    final List<IconData> vapingIcons = [
      Icons.person,
      Icons.settings,
      Icons.image,
      Icons.house,
      Icons.credit_card,
      Icons.notifications,
      Icons.favorite,
      Icons.security,
    ];

    return Container(
      color: Colors.black.withOpacity(0.8), // Réduit encore un peu le noir
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Fond d'étoiles/particules qui disparaissent (version ralentie)
            ...List.generate(20, (index) {
              final random = Random();
              return Positioned(
                left: MediaQuery.of(context).size.width / 2 + (random.nextDouble() - 0.5) * 40,
                top: MediaQuery.of(context).size.height / 2 + (random.nextDouble() - 0.5) * 40,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ).animate(delay: (index * 150).ms)
                    .move(
                    begin: Offset.zero,
                    end: Offset((random.nextDouble() - 0.5) * 400, (random.nextDouble() - 0.5) * 400),
                    duration: 5000.ms, // Temps doublé
                    curve: Curves.easeOutQuart
                )
                    .fadeOut(duration: 5000.ms)
                    .scale(begin: Offset(1,1), end: Offset(0,0)),
              );
            }),

            // Icônes du compte qui s'envolent au ralenti
            ...vapingIcons.asMap().entries.map((entry) {
              final idx = entry.key;
              final icon = entry.value;
              final random = Random(idx);

              return Icon(icon, color: Colors.white70, size: 30)
                  .animate(delay: (idx * 500).ms) // Plus d'espace entre les envolées
                  .fadeIn(duration: 800.ms)
                  .scale(begin: Offset(0,0), end: Offset(1.2, 1.2), duration: 1000.ms, curve: Curves.easeOutBack)
                  .then(delay: 200.ms)
                  .move(
                  begin: Offset.zero,
                  end: Offset((random.nextDouble() - 0.5) * 600, (random.nextDouble() - 1.5) * 600),
                  duration: 5000.ms, // Ralenti extrême
                  curve: Curves.easeOutCubic
              )
                  .fadeOut(duration: 4000.ms)
                  .scale(begin: Offset(1.2, 1.2), end: Offset(0,0), duration: 5000.ms);
            }),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 100),
                Text(
                  "SUPPRESSION DU COMPTE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ).animate().fadeIn(duration: 1500.ms).shimmer(delay: 2000.ms, duration: 2500.ms),

                SizedBox(height: 12),

                Text(
                  "Suppression définitive de vos données...",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    letterSpacing: 1.1,
                  ),
                ).animate().fadeIn(delay: 800.ms, duration: 1500.ms),

                SizedBox(height: 48),

                // Barre de vuidage au ralenti
                Container(
                  width: 240,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 2,
                      width: 240,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _primaryColor.withOpacity(0.85),
                              _primaryColor.withOpacity(0.35),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.35),
                              blurRadius: 10,
                            )
                          ]
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: false)).custom(
                      duration: 7000.ms, // Aligné sur le délai global
                      builder: (context, value, child) => FractionallySizedBox(
                        widthFactor: value,
                        alignment: Alignment.centerLeft,
                        child: Container(color: _primaryColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 800.ms);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final defaultStyle = theme.textTheme.bodyMedium ?? const TextStyle();

    return DefaultTextStyle(
      style: defaultStyle,
      child: Scaffold(
        backgroundColor: isDarkMode ? _darkColor : _lightColor,
        body: Stack(
          children: [
            _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : Positioned.fill(
              child: RefreshConfiguration(
                enableScrollWhenRefreshCompleted: true,
                child: SmartRefresher(
                  controller: _profileRefreshController,
                  enablePullDown: true,
                  enablePullUp: false,
                  header: WaterDropMaterialHeader(
                    backgroundColor: _primaryColor,
                    color: Colors.white,
                  ),
                  onRefresh: _handleProfileRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80),
                    children: [
                      _buildProfileHeader(),
                      Transform.translate(
                        offset: const Offset(0, -30),
                        child: Column(
                          children: [
                            _buildProfileCompletionCard(),
                            _buildStatsCard(),
                            const SizedBox(height: 16),
                            _buildProfileInfoCard(),
                            _buildAuthOptions(),
                            _buildSettingsMenu(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isDeleting) _buildDeletionOverlay(),
          ],
        ),
      ),
    );
  }
}

class CompleteProfileScreen extends StatefulWidget {
  final VoidCallback onProfileUpdated;

  const CompleteProfileScreen({Key? key, required this.onProfileUpdated}) : super(key: key);

  @override
  _CompleteProfileScreenState createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> with SingleTickerProviderStateMixin {
  final GetStorage storage = GetStorage();
  final ImagePicker _picker = ImagePicker();

  // Contrôleurs
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();

  // Variables d'état
  File? _profileImage;
  File? _cardFrontImage;
  File? _cardBackImage;
  String? _selectedCardType;
  int _currentStep = 0;
  bool _isLoading = false;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  // Couleurs
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _accentColor = Color(0xFF00C853);
  final Color _darkColor = Color(0xFF2D3748);
  final Color _lightColor = Color(0xFFF7FAFC);
  final Color _greyColor = Color(0xFF718096);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFE2E8F0);
  final Color _errorColor = Color(0xFFE53E3E);

  // Types de cartes
  final List<Map<String, dynamic>> _cardTypes = [
    {
      'id': 1,
      'name': 'Carte d\'électeur',
      'icon': Icons.credit_card,
      'color': Color(0xFF4299E1)
    },
    {
      'id': 2,
      'name': 'Passeport',
      'icon': Icons.airplane_ticket,
      'color': Color(0xFF48BB78)
    },
    {
      'id': 3,
      'name': 'Permis de Conduire',
      'icon': Icons.directions_car,
      'color': Color(0xFFED8936)
    },
    {
      'id': 4,
      'name': 'Carte de Séjour',
      'icon': Icons.badge,
      'color': Color(0xFF9F7AEA)
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _loadExistingData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _addressController.dispose();
    _cardNumberController.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    final userData = storage.read('user_data') ?? {};
    setState(() {
      _addressController.text = userData['address'] ?? '';
      _cardNumberController.text = userData['cardNumber'] ?? '';
      _selectedCardType = userData['cardType'];

      // Charger les images existantes
      final profilePath = storage.read('profile_image_path');
      final cardFrontPath = storage.read('card_front_path');
      final cardBackPath = storage.read('card_back_path');

      if (profilePath != null) _profileImage = File(profilePath);
      if (cardFrontPath != null) _cardFrontImage = File(cardFrontPath);
      if (cardBackPath != null) _cardBackImage = File(cardBackPath);
    });
    _updateProgress();
  }

  Future<void> _pickImage(ImageSource source, {bool isProfile = false, bool isFront = true}) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          if (isProfile) {
            _profileImage = File(pickedFile.path);
          } else if (isFront) {
            _cardFrontImage = File(pickedFile.path);
          } else {
            _cardBackImage = File(pickedFile.path);
          }
        });
        _updateProgress();
      }
    } catch (e) {
      _showErrorSnackbar(
        'L’image n’a pas pu être sélectionnée. Réessayez avec une autre photo.',
      );
    }
  }

  void _updateProgress() {
    int completedFields = 0;
    int totalFields = 5; // Image profil, adresse, type carte, recto, verso

    if (_profileImage != null) completedFields++;
    if (_addressController.text.isNotEmpty) completedFields++;
    if (_selectedCardType != null) completedFields++;
    if (_cardFrontImage != null) completedFields++;
    if (_cardBackImage != null) completedFields++;

    final progress = completedFields / totalFields;
    _animationController.animateTo(progress);
  }

  double get _completionPercentage {
    int completedFields = 0;
    int totalFields = 5;

    if (_profileImage != null) completedFields++;
    if (_addressController.text.isNotEmpty) completedFields++;
    if (_selectedCardType != null) completedFields++;
    if (_cardFrontImage != null) completedFields++;
    if (_cardBackImage != null) completedFields++;

    return completedFields / totalFields;
  }

  Widget _buildProgressIndicator() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progression du profil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
              Text(
                '${(_completionPercentage * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: _borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Container(
                    height: 8,
                    width: MediaQuery.of(context).size.width * _progressAnimation.value,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStepCircle(0, 'Photo'),
          _buildStepLine(),
          _buildStepCircle(1, 'Adresse'),
          _buildStepLine(),
          _buildStepCircle(2, 'Carte'),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int stepIndex, String label) {
    bool isActive = stepIndex == _currentStep;
    bool isCompleted = stepIndex < _currentStep;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted ? _accentColor : (isActive ? _primaryColor : _greyColor.withOpacity(0.3)),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? _primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
              '${stepIndex + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : _greyColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? _primaryColor : _greyColor,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Expanded(
      child: Container(
        height: 2,
        color: _borderColor,
        margin: EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildProfilePhotoStep() {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: _profileImage == null
          ? _buildEmptyPhotoCard()
          : _buildPhotoWithPreview(),
    );
  }

  Widget _buildEmptyPhotoCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _lightColor,
              border: Border.all(color: _borderColor, width: 2),
            ),
            child: Icon(
              Icons.person_add_alt_1,
              size: 40,
              color: _greyColor,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Ajoutez une photo de profil',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Une photo vous aidera à être reconnu par la communauté',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _greyColor,
            ),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildImagePickerButton(
                icon: Icons.photo_library,
                label: 'Galerie',
                onTap: () => _pickImage(ImageSource.gallery, isProfile: true),
              ),
              _buildImagePickerButton(
                icon: Icons.camera_alt,
                label: 'Caméra',
                onTap: () => _pickImage(ImageSource.camera, isProfile: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoWithPreview() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _primaryColor, width: 3),
                ),
                child: ClipOval(
                  child: Image.file(
                    _profileImage!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.edit, color: Colors.white, size: 20),
                    onPressed: () => _showImageSourceModal(isProfile: true),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Photo de profil ajoutée ✓',
            style: TextStyle(
              color: _accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressStep() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: _primaryColor),
              SizedBox(width: 12),
              Text(
                'Adresse',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextField(
            controller: _addressController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Entrez votre adresse complète...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              contentPadding: EdgeInsets.all(16),
            ),
            onChanged: (value) => _updateProgress(),
          ),
          SizedBox(height: 8),
          Text(
            'Cette information nous aide à personnaliser votre expérience',
            style: TextStyle(
              color: _greyColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTypeStep() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          _buildCardTypeSelection(),
          SizedBox(height: 16),
          if (_selectedCardType != null) ...[
            _buildCardNumberField(),
            SizedBox(height: 16),
            _buildCardPhotosSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildCardTypeSelection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card, color: _primaryColor),
              SizedBox(width: 12),
              Text(
                'Type de pièce d\'identité',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2, // Ratio pour des cartes carrées
            children: _cardTypes.map((cardType) {
              bool isSelected = _selectedCardType == cardType['name'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCardType = cardType['name'];
                  });
                  _updateProgress();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? (cardType['color'] as Color).withOpacity(0.1) : _lightColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? cardType['color'] as Color : _borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: (cardType['color'] as Color).withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected ? cardType['color'] as Color : (cardType['color'] as Color).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          cardType['icon'] as IconData,
                          color: isSelected ? Colors.white : cardType['color'] as Color,
                          size: 24,
                        ),
                      ),
                      SizedBox(height: 12),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          cardType['name'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: _darkColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected) ...[
                        SizedBox(height: 8),
                        Icon(
                          Icons.check_circle,
                          color: cardType['color'] as Color,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Version alternative avec Row et Expanded (plus simple)
          /*
        Column(
          children: [
            for (int i = 0; i < _cardTypes.length; i += 2)
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCardTypeItem(_cardTypes[i]),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: i + 1 < _cardTypes.length
                          ? _buildCardTypeItem(_cardTypes[i + 1])
                          : SizedBox(),
                    ),
                  ],
                ),
              ),
          ],
        ),
        */
        ],
      ),
    );
  }

// Méthode helper pour construire un item de type de carte (pour la version alternative)
  Widget _buildCardTypeItem(Map<String, dynamic> cardType) {
    bool isSelected = _selectedCardType == cardType['name'];
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCardType = cardType['name'];
        });
        _updateProgress();
      },
      child: Container(
        height: 120, // Hauteur fixe pour uniformité
        decoration: BoxDecoration(
          color: isSelected ? (cardType['color'] as Color).withOpacity(0.1) : _lightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cardType['color'] as Color : _borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? cardType['color'] as Color : (cardType['color'] as Color).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                cardType['icon'] as IconData,
                color: isSelected ? Colors.white : cardType['color'] as Color,
                size: 24,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                cardType['name'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: _darkColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardNumberField() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.numbers, color: _primaryColor),
              SizedBox(width: 12),
              Text(
                'Numéro de la carte',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          TextField(
            controller: _cardNumberController,
            decoration: InputDecoration(
              hintText: 'Entrez le numéro de votre pièce...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
            ),
            onChanged: (value) => _updateProgress(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPhotosSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library, color: _primaryColor),
              SizedBox(width: 12),
              Text(
                'Photos de la pièce d\'identité',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCardPhotoItem(
                  image: _cardFrontImage,
                  label: 'Recto',
                  isFront: true,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildCardPhotoItem(
                  image: _cardBackImage,
                  label: 'Verso',
                  isFront: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardPhotoItem({File? image, required String label, required bool isFront}) {
    return Column(
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            border: Border.all(
              color: image != null ? _accentColor : _borderColor,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            color: _lightColor,
          ),
          child: image != null
              ? ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(image, fit: BoxFit.cover),
          )
              : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFront ? Icons.credit_card : Icons.credit_card_outlined,
                  size: 40,
                  color: _greyColor,
                ),
                SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(color: _greyColor),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => _showIdentityCardCameraModal(isFront: isFront),
          style: ElevatedButton.styleFrom(
            backgroundColor: image != null ? _accentColor : _primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: Size(double.infinity, 40),
          ),
          child: Text(
            image != null ? 'Modifier' : 'Ajouter',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickerButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }


  void _showIdentityCardCameraModal({required bool isFront}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête avec indication du côté à photographier
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: _primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isFront ? 'Photographiez le recto de la pièce' : 'Photographiez le verso de la pièce',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _darkColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Instructions détaillées
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _lightColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conseils pour une photo optimale :',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _darkColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildTipItem('Placez la pièce sur une surface plane'),
                  _buildTipItem('Assurez un bon éclairage'),
                  _buildTipItem('Photo nette et sans reflet'),
                  _buildTipItem('Cadrez toute la pièce'),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Bouton caméra principal
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, isProfile: false, isFront: isFront);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Ouvrir la caméra',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),

            // Bouton annuler
            Container(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Annuler',
                  style: TextStyle(
                    fontSize: 16,
                    color: _greyColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: _greyColor,
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showImageSourceModal({bool isProfile = false, bool isFront = true}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choisir une source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.photo_library,
                    label: 'Galerie',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery, isProfile: isProfile, isFront: isFront);
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.camera_alt,
                    label: 'Caméra',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera, isProfile: isProfile, isFront: isFront);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: _greyColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightColor,
        foregroundColor: _darkColor,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _borderColor),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    // Obtenir la hauteur de la barre de navigation système
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      margin: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 16 + bottomPadding, // Ajouter le padding pour la barre de navigation
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: ElevatedButton(
                onPressed: _goToPreviousStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _lightColor,
                  foregroundColor: _darkColor,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _borderColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back, size: 20),
                    SizedBox(width: 8),
                    Text('Précédent'),
                  ],
                ),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _goToNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_currentStep == 2 ? 'Terminer' : 'Suivant'),
                  if (_currentStep < 2) SizedBox(width: 8),
                  if (_currentStep < 2) Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _goToNextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else {
      _saveProfile();
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simuler un appel API
      await Future.delayed(Duration(seconds: 2));

      // Sauvegarder les données localement
      final currentUserData = storage.read('user_data') ?? {};
      final updatedUserData = {
        ...currentUserData,
        'address': _addressController.text,
        'cardType': _selectedCardType,
        'cardNumber': _cardNumberController.text,
        'profileCompleted': true,
      };

      await storage.write('user_data', updatedUserData);

      // Sauvegarder les chemins des images
      if (_profileImage != null) {
        await storage.write('profile_image_path', _profileImage!.path);
      }
      if (_cardFrontImage != null) {
        await storage.write('card_front_path', _cardFrontImage!.path);
      }
      if (_cardBackImage != null) {
        await storage.write('card_back_path', _cardBackImage!.path);
      }

      widget.onProfileUpdated();

      _showSuccessSnackbar('Profil complété avec succès !');

      // Retour à l'écran précédent après un délai
      await Future.delayed(Duration(seconds: 1));
      Navigator.pop(context);

    } catch (e) {
      _showErrorSnackbar(
        'La sauvegarde n’a pas abouti. Vérifiez la connexion et réessayez.',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: _accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    SnackbarForCasa.error(context, message);
  }

  List<Widget> get _stepContents => [
    _buildProfilePhotoStep(),
    _buildAddressStep(),
    _buildCardTypeStep(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _darkColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Compléter le profil',
          style: TextStyle(
            color: _darkColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            SizedBox(height: 16),
            Text(
              'Sauvegarde en cours...',
              style: TextStyle(
                color: _greyColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Column(
          children: [
            _buildProgressIndicator(),
            _buildStepIndicator(),
            SizedBox(height: 24),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: _stepContents[_currentStep],
            ),
            _buildNavigationButtons(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Page de modification de profil
class EditProfilePage extends StatefulWidget {
  final String accountType;
  final int? profileId;
  final VoidCallback onProfileUpdated;

  const EditProfilePage({
    Key? key,
    required this.accountType,
    required this.profileId,
    required this.onProfileUpdated,
  }) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final GetStorage storage = GetStorage();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _numberCardController = TextEditingController();

  bool _isLoading = false;

  final Color _primaryColor = Color(0xFF1976D2);
  final Color _darkColor = Color(0xFF2D3748);
  final Color _lightColor = Color(0xFFF7FAFC);
  final Color _greyColor = Color(0xFF718096);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFE2E8F0);
  final Color _errorColor = Color(0xFFE53E3E);
  final Color _successColor = Color(0xFF48BB78);

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _numberCardController.dispose();
    super.dispose();
  }

  bool get _isUserCertified {
    final userData = storage.read(StockageKeys.userKey);
    return userData?['isCertified'] == true || userData?['certified'] == true;
  }

  void _loadProfileData() {
    final profileData = storage.read(StockageKeys.profileKey);
    final userData = storage.read(StockageKeys.userKey);

    if (profileData != null) {
      setState(() {
        _firstNameController.text = profileData['firstname']?.toString() ?? '';
        _lastNameController.text = profileData['lastname']?.toString() ?? '';
        _addressController.text = profileData['address']?.toString() ?? '';
        // Si l'utilisateur est certifié, on ne charge pas numberCard dans l'UI mais on le garde pour le payload
        if (!_isUserCertified) {
          _numberCardController.text = profileData['numberCard']?.toString() ?? '';
        }
      });
    }

    // Charger aussi les données utilisateur si disponibles
    if (userData != null) {
      // Les données utilisateur sont déjà chargées, on peut les utiliser dans le payload
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.profileId == null) {
      // Debug: afficher les données disponibles
      final profileData = storage.read(StockageKeys.profileKey);
      final userData = storage.read(StockageKeys.userKey);
      print("❌ Profile ID non trouvé");
      print("📋 Account Type: ${widget.accountType}");
      print("📋 Profile Data: $profileData");
      print("📋 User Data: $userData");

      FancyNotification.show(
        context,
        "Impossible de modifier le profil : ID non trouvé pour le type de compte '${widget.accountType}'. Veuillez vous reconnecter.",
        isError: true,
      );
      return;
    }

    print("✅ Profile ID trouvé: ${widget.profileId} pour le type: ${widget.accountType}");

    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer les données utilisateur depuis le storage
      final userData = storage.read(StockageKeys.userKey) ?? {};
      final profileData = storage.read(StockageKeys.profileKey) ?? {};

      // Construire le payload selon la structure de l'API
      final accountTypeLower = widget.accountType.toLowerCase();

      // Déterminer la clé de l'ID selon le type de compte
      String profileIdKey = '${accountTypeLower}Id';
      if (accountTypeLower == 'salubrité' || accountTypeLower == 'salubrite') {
        profileIdKey = 'salubriteId';
      } else if (accountTypeLower == 'menusier' || accountTypeLower == 'menuisier') {
        profileIdKey = 'menuisierId';
      } else if (accountTypeLower == 'architect' || accountTypeLower == 'architecte') {
        profileIdKey = 'architecteId';
      }

      // Récupérer l'ID du profil depuis les données stockées ou utiliser le profileId
      int? existingProfileId = profileData[profileIdKey] ?? widget.profileId;

      // Construire le payload complet selon la structure de l'API
      // Même structure pour vérification et modification
      // Si l'utilisateur est certifié, on utilise les valeurs existantes pour les cartes
      final isCertified = _isUserCertified;

      // Récupérer les valeurs existantes des cartes depuis le profil
      final existingCardFront = profileData['cardFront']?.toString() ?? "";
      final existingCardBack = profileData['cardBack']?.toString() ?? "";
      final existingTypeCardId = profileData['typeCardId'] ?? profileData['type_card_id'] ?? profileData['typeCard']?['typeCardId'] ?? 1;
      final existingNumberCard = isCertified
          ? (profileData['numberCard']?.toString() ?? "")
          : _numberCardController.text.trim();

      // Récupérer le parrainId existant
      final parrainId = profileData['parrain_id'] ?? profileData['parrainId'] ?? 0;

      // Structure du payload identique pour vérification et modification
      Map<String, dynamic> payload = {
        "lastName": _lastNameController.text.trim(),
        "firstName": _firstNameController.text.trim(),
        "address": _addressController.text.trim(),
        "images": profileData['images']?.toString() ?? "", // Photo de profil en base64
        "cardFront": existingCardFront, // Valeur existante si certifié, sinon vide
        "cardBack": existingCardBack, // Valeur existante si certifié, sinon vide
        "typeCardId": existingTypeCardId, // Valeur existante si certifié
        "type_card_id": existingTypeCardId, // Fallback snake_case
        "parrainId": parrainId,
        "parrain_id": parrainId, // Fallback snake_case
        "numberCard": existingNumberCard, // Valeur existante si certifié, sinon depuis le controller
        "number_card": existingNumberCard, // Fallback snake_case
        // La clé "user" doit toujours être présente avec toutes ses propriétés (même vides)
        // Si l'email est vide, envoyer "string" pour éviter l'erreur API
        "user": {
          "email": (userData['email']?.toString() ?? "").isEmpty ? "string" : userData['email']?.toString() ?? "",
          "phone": userData['phone']?.toString() ?? "",
          "city": userData['city']?.toString() ?? "",
          "country": userData['country']?.toString() ?? "",
        },
      };

      // Ajouter des champs spécifiques selon le type de compte
      if (accountTypeLower == 'bailleur') {
        payload["note"] = profileData['note']?.toString() ?? "";
      }

      HttpResponse? response;

      // Appeler la méthode appropriée selon le type de compte
      if (accountTypeLower == 'bailleur') {
        final ctrl = context.read<RegisterBailleurCtrl>();
        response = await ctrl.updateBailleurProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'locataire') {
        final ctrl = context.read<RegisterLocataireCtrl>();
        response = await ctrl.updateLocataireProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'commissionnaire') {
        final ctrl = context.read<RegisterCommissionnaireCtrl>();
        response = await ctrl.updateCommissionnaireProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'plombier') {
        final ctrl = context.read<RegisterPlombierCtrl>();
        response = await ctrl.updatePlombierProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'electricien') {
        final ctrl = context.read<RegisterElectricienCtrl>();
        response = await ctrl.updateElectricienProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'salubrité' || accountTypeLower == 'salubrite') {
        final ctrl = context.read<RegisterSalubriteCtrl>();
        response = await ctrl.updateSalubriteProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'chauffeur') {
        final ctrl = context.read<RegisterChauffeurCtrl>();
        response = await ctrl.updateChauffeurProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'majordome') {
        final ctrl = context.read<RegisterMajordomeCtrl>();
        response = await ctrl.updateMajordomeProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'peintre') {
        final ctrl = context.read<RegisterPeintreCtrl>();
        response = await ctrl.updatePeintreProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'carreleur' || accountTypeLower == 'coiffure') {
        final ctrl = context.read<RegisterCarreleurCtrl>();
        response = await ctrl.updateCarreleurProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'menusier' || accountTypeLower == 'menuisier') {
        final ctrl = context.read<RegisterMenuisierCtrl>();
        response = await ctrl.updateMenuisierProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'frigoriste') {
        final ctrl = context.read<RegisterFrigoristeCtrl>();
        response = await ctrl.updateFrigoristeProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'ajusteur') {
        final ctrl = context.read<RegisterAjusteurCtrl>();
        response = await ctrl.updateAjusteurProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'architect' || accountTypeLower == 'architecte') {
        final ctrl = context.read<RegisterArchitecteCtrl>();
        response = await ctrl.updateArchitecteProfile(widget.profileId!, payload);
      } else if (accountTypeLower == 'demenagement') {
        final ctrl = context.read<RegisterDemenagementCtrl>();
        response = await ctrl.updateDemenagementProfile(widget.profileId!, payload);
      } else {
        FancyNotification.show(
          context,
          "Type de compte non pris en charge : ${widget.accountType}",
          isError: true,
        );
        return;
      }

      if (response != null && response.status) {
        // Mettre à jour les données locales
        final profileData = storage.read(StockageKeys.profileKey) ?? {};
        profileData['firstname'] = _firstNameController.text.trim();
        profileData['lastname'] = _lastNameController.text.trim();
        profileData['fullname'] = "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";
        profileData['address'] = _addressController.text.trim();
        profileData['numberCard'] = _numberCardController.text.trim();
        await storage.write(StockageKeys.profileKey, profileData);

        FancyNotification.show(
          context,
          response.errorMsg ?? "Profil modifié avec succès",
          isError: false,
          type: NotificationType.success,
        );

        widget.onProfileUpdated();
        Navigator.pop(context);
      } else {
        FancyNotification.show(
          context,
          response?.errorMsg ??
              "Les modifications n’ont pas pu être enregistrées. Réessayez.",
          isError: true,
        );
      }
    } catch (e) {
      print("❌ Erreur lors de la modification: $e");
      FancyNotification.show(
        context,
        "L’enregistrement du profil a été interrompu. Vérifiez la connexion et réessayez.",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _errorColor),
          ),
          filled: true,
          fillColor: _cardColor,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Ce champ est requis';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Modifier le profil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            SizedBox(height: 16),
            Text(
              'Modification en cours...',
              style: TextStyle(color: _greyColor),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec type de compte
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: _primaryColor),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Type de compte',
                            style: TextStyle(
                              fontSize: 12,
                              color: _greyColor,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.accountType,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Champs du formulaire
              _buildTextField(
                controller: _firstNameController,
                label: 'Prénom',
                icon: Icons.person_outline,
                hint: 'Entrez votre prénom',
              ),
              _buildTextField(
                controller: _lastNameController,
                label: 'Nom',
                icon: Icons.person_outline,
                hint: 'Entrez votre nom',
              ),
              _buildTextField(
                controller: _addressController,
                label: 'Adresse',
                icon: Icons.location_on_outlined,
                hint: 'Entrez votre adresse',
                maxLines: 2,
              ),
              // Afficher les champs de carte uniquement si l'utilisateur n'est pas certifié
              if (!_isUserCertified)
                _buildTextField(
                  controller: _numberCardController,
                  label: 'Numéro de carte',
                  icon: Icons.credit_card_outlined,
                  hint: 'Entrez le numéro de votre pièce d\'identité',
                  keyboardType: TextInputType.text,
                ),

              SizedBox(height: 32),

              // Bouton de sauvegarde
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Enregistrer les modifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}