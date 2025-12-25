import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

import '../utils/Routes.dart';
import '../controllers/AuthentificationCtrl.dart';
import 'camera/SelfieCameraScreen.dart';
import 'auth/IdentityVerificationPage.dart';
import '../utils/StockageKeys.dart';
import '../utils/database/FavoriteDatabaseHelper.dart';
import '../utils/database/ReservationDatabaseHelper.dart';
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

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
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
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  double _profileCompletion = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _calculateProfileCompletion();
  }

  void _loadSavedData() async {
    final imagePath = storage.read('user_image_path');
    if (imagePath != null) {
      setState(() {
        _imageFile = File(imagePath);
      });
    }
  }

  void _calculateProfileCompletion() {
    int completedFields = 0;
    int totalFields = 6; // Photo, Address, Card Type, Card Number, Card Front, Card Back

    final profileData = storage.read(StockageKeys.profileKey) ?? {};
    final userData = storage.read(StockageKeys.userKey) ?? {};

    // 1. Profile Photo (check file or profile data)
    bool hasPhoto = _imageFile != null || (profileData['image'] != null && profileData['image'].toString().isNotEmpty);
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
    
    // Si l'utilisateur est certifié, on considère que c'est 100%
    if (userData['isCertified'] == true || userData['isVerified'] == true) {
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

    // Priorité aux données du profil, puis user
    return profileData?['fullname']?.toString() ??
        userData?['username']?.toString() ??
        'Visiteur';
  }

  String get safeEmail {
    final userData = storage.read(StockageKeys.userKey);
    return userData?['email']?.toString() ?? 'Non connecté';
  }

  String get safePhone {
    final userData = storage.read(StockageKeys.userKey);
    return userData?['phone']?.toString() ?? '';
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
       final Set<String> types = {};
       for (var acc in accounts) {
         if (acc is Map && acc['typeAccount'] != null) {
            String? name = acc['typeAccount']['name']?.toString();
            if (name != null && name.isNotEmpty) types.add(name);
         }
       }
       if (types.isNotEmpty) {
         return types.join(' & ');
       }
    }
    return accountType;
  }

  Map<String, dynamic>? get profileData {
    return storage.read(StockageKeys.profileKey);
  }

  int? get profileId {
    final userData = storage.read(StockageKeys.userKey);
    
    // L'ID du profil est le userId pour tous les types de comptes
    // Les endpoints PUT utilisent le userId (ex: /api/bailleurs/{userId})
    if (userData != null && userData['userId'] != null) {
      final userId = userData['userId'];
      if (userId is int) return userId;
      if (userId is String) return int.tryParse(userId);
    }
    
    // Fallback: chercher dans le profile si userId n'est pas disponible
    final profile = profileData;
    if (profile != null && profile['userId'] != null) {
      final userId = profile['userId'];
      if (userId is int) return userId;
      if (userId is String) return int.tryParse(userId);
    }
    
    return null;
  }

  String get publishedProperties {
    return storage.read('published_properties_count')?.toString() ?? '0';
  }

  String get referralsCount {
    return storage.read('referrals_count')?.toString() ?? '0';
  }


  Future<void> _pickImage() async {
    // Navigate to custom Selfie Camera
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelfieCameraScreen(
          onImageCaptured: (path) async {
            setState(() {
              _imageFile = File(path);
            });
            await storage.write('user_image_path', path);
            _calculateProfileCompletion();

            // S'il y a un profileId (ou userId utilisé comme tel), maj via API
            if (profileId != null) {
              try {
                final bytes = await File(path).readAsBytes();
                final base64Image = base64Encode(bytes);
                final authCtrl = context.read<AuthentificationCtrl>();
                
                // Appel à l'endpoint spécifique pour la photo
                await authCtrl.updateProfilePicture(profileId!, base64Image);
                
                FancyNotification.show(context, "Photo de profil mise à jour !", isError: false);
              } catch (e) {
                print("Erreur upload photo: $e");
                // On ne bloque pas l'UI pour ça, c'est une maj en background
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildProfileCompletionCard() {
    if (!isLoggedIn || _profileCompletion >= 1.0) return SizedBox.shrink();

    return Container(
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
            onTap: _pickImage,
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
                  child: ClipOval(
                    child: _imageFile != null
                        ? Image.file(_imageFile!, fit: BoxFit.cover)
                        : Container(
                      color: Colors.white.withOpacity(0.2),
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: _cardColor,
                      ),
                    ),
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
          SizedBox(height: 16),
          Text(
            safeUsername,
            style: TextStyle(
              color: _cardColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            bio.isNotEmpty ? bio : 'Ajoutez une bio pour personnaliser votre profil',
            style: TextStyle(
              color: _cardColor.withOpacity(0.9),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
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
      padding: EdgeInsets.all(20),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            value: publishedProperties,
            label: 'Publications',
            icon: Icons.home_work_outlined,
            color: _primaryColor,
          ),
          _buildStatItem(
            value: referralsCount,
            label: 'Parrainages',
            icon: Icons.people_outline,
            color: _secondaryColor,
          ),
          _buildStatItem(
            value: '${(_profileCompletion * 100).toInt()}%',
            label: 'Profil',
            icon: Icons.person_outline,
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
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _greyColor,
          ),
        ),
      ],
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
  }) {
    return Row(
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
          ),
      ],
    );
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

  Widget _buildDarkModeSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      child: _buildDarkModeToggle(),
    );
  }

  Widget _buildSettingsSection() {
    if (!isLoggedIn) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
          _buildSettingItem(
            icon: Icons.edit_outlined,
            title: 'Modifier mon profil',
            onTap: _navigateToEditProfile,
            color: _primaryColor,
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: _borderColor),
          _buildSettingItem(
            icon: Icons.settings_outlined,
            title: 'Paramètres du compte',
            onTap: () {},
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: _borderColor),
          _buildSettingItem(
            icon: Icons.share_outlined,
            title: 'Partager l\'application',
            onTap: () {},
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: _borderColor),
          _buildSettingItem(
            icon: Icons.star_outline,
            title: 'Évaluer l\'application',
            onTap: () {},
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: _borderColor),
          _buildSettingItem(
            icon: Icons.logout,
            title: 'Déconnexion',
            onTap: _confirmLogout,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? _primaryColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: color ?? _darkColor,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: _greyColor),
      onTap: onTap,
    );
  }

  Widget _buildDarkModeToggle() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Consumer<ThemeController>(
      builder: (context, themeController, child) {
        final isDark = themeController.isDarkMode;
        return ListTile(
          leading: Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            color: _primaryColor,
          ),
          title: Text(
            'Mode sombre',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : _darkColor,
            ),
          ),
          trailing: Switch(
            value: isDark,
            onChanged: (value) {
              themeController.toggleTheme();
            },
            activeColor: _primaryColor,
          ),
        );
      },
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
      await storage.remove('published_properties_count');
      await storage.remove('referrals_count');

      await FavoriteDatabaseHelper.instance.clearAllFavorites();
      await ReservationDatabaseHelper.instance.clearAllReservations();

      // 3. Supprimer TOUS les brouillons lors de la déconnexion
      try {
        await DraftHelper.clearAllDrafts();
        print("✅ Tous les brouillons supprimés");
      } catch (e) {
        print("⚠️ Erreur lors de la suppression des brouillons: $e");
      }

      // 4. Réinitialiser l'état local
      setState(() {
        _imageFile = null;
        _profileCompletion = 0.0;
      });

      print("✅ Données d'authentification, cache du profil et bases de données locales supprimées");
    } catch (e) {
      print("❌ Erreur lors du nettoyage des données locales: $e");
      throw e;
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => _performLogout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    // Fermer la dialog d'abord
    Navigator.pop(context);

    try {
      // 1. Nettoyer les données
      await _clearLocalAuthData();

      // 2. Naviguer directement vers la page d'accueil (onglet accueil dans bottomPage)
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.bottomPageRoute,
          (route) => false,
        );
      }

    } catch (e) {
      print("❌ Erreur lors de la déconnexion: $e");

      // Même en cas d'erreur, naviguer vers la page d'accueil
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.bottomPageRoute,
          (route) => false,
        );
      }
    }
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
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: _primaryColor))
            : SingleChildScrollView(
          child: Column(
            children: [
              _buildProfileHeader(),
              SizedBox(height: 16),
              _buildProfileCompletionCard(),
              _buildStatsCard(),
              SizedBox(height: 16),
              _buildProfileInfoCard(),
              _buildAuthOptions(),
              _buildDarkModeSection(),
              _buildSettingsSection(),
              SizedBox(height: 20),
            ],
          ),
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
      _showErrorSnackbar('Erreur lors de la sélection de l\'image: $e');
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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      _showErrorSnackbar('Erreur lors de la sauvegarde: $e');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
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

  void _loadProfileData() {
    final profileData = storage.read(StockageKeys.profileKey);
    final userData = storage.read(StockageKeys.userKey);
    
    if (profileData != null) {
      setState(() {
        _firstNameController.text = profileData['firstname']?.toString() ?? '';
        _lastNameController.text = profileData['lastname']?.toString() ?? '';
        _addressController.text = profileData['address']?.toString() ?? '';
        _numberCardController.text = profileData['numberCard']?.toString() ?? '';
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
      Map<String, dynamic> payload = {
        profileIdKey: existingProfileId ?? widget.profileId ?? 0, // ID du profil (non modifié)
        "firstName": _firstNameController.text.trim(),
        "lastName": _lastNameController.text.trim(),
        "fullName": "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}",
        "address": _addressController.text.trim(),
        "images": profileData['images']?.toString() ?? "",
        "cardFront": profileData['cardFront']?.toString() ?? "",
        "cardBack": profileData['cardBack']?.toString() ?? "",
        "numberCard": _numberCardController.text.trim().isNotEmpty ? _numberCardController.text.trim() : "",
        "user": {
          "userId": userData['userId'] ?? widget.profileId ?? 0,
          "typeAccount": userData['typeAccount'] ?? {
            "typeAccountId": 0,
            "name": widget.accountType
          },
          "email": userData['email']?.toString() ?? "",
          "username": userData['username']?.toString() ?? "",
          "phone": userData['phone']?.toString() ?? "",
          "city": userData['city']?.toString() ?? "",
          "country": userData['country']?.toString() ?? "",
          "isPremium": userData['isPremium'] ?? false,
          "isCertified": userData['isCertified'] ?? false,
        },
        "typeCard": {
          "typeCardId": profileData['typeCard']?['typeCardId'] ?? 1,
          "name": profileData['typeCard']?['name']?.toString() ?? "Carte d'identité"
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
      } else if (accountTypeLower == 'carreleur') {
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
        );

        widget.onProfileUpdated();
        Navigator.pop(context);
      } else {
        FancyNotification.show(
          context,
          response?.errorMsg ?? "Erreur lors de la modification du profil",
          isError: true,
        );
      }
    } catch (e) {
      print("❌ Erreur lors de la modification: $e");
      FancyNotification.show(
        context,
        "Erreur technique lors de la modification du profil",
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