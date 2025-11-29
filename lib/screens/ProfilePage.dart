import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../utils/Routes.dart';
import '../utils/StockageKeys.dart';
import '../utils/database/FavoriteDatabaseHelper.dart';
import '../utils/database/ReservationDatabaseHelper.dart';
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
    int totalFields = 6; // Nombre total de champs du profil

    final userData = storage.read('user_data') ?? {};

    if (userData['username']?.toString().isNotEmpty == true) completedFields++;
    if (userData['email']?.toString().isNotEmpty == true) completedFields++;
    if (userData['phone']?.toString().isNotEmpty == true) completedFields++;
    if (userData['address']?.toString().isNotEmpty == true) completedFields++;
    if (userData['bio']?.toString().isNotEmpty == true) completedFields++;
    if (_imageFile != null) completedFields++;

    setState(() {
      _profileCompletion = completedFields / totalFields;
    });
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

  String get publishedProperties {
    return storage.read('published_properties_count')?.toString() ?? '0';
  }

  String get referralsCount {
    return storage.read('referrals_count')?.toString() ?? '0';
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      await storage.write('user_image_path', pickedFile.path);
      _calculateProfileCompletion();
    }
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
                onPressed: _navigateToCompleteProfile,
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
          SizedBox(height: 16),
          if (isLoggedIn) _buildEditProfileButton(),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEditProfileButton() {
    return Container(
      width: 140,
      height: 36,
      child: ElevatedButton(
        onPressed: _navigateToCompleteProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: _cardColor,
          foregroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 2,
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit, size: 16),
            SizedBox(width: 6),
            Text(
              'Modifier',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
            icon: Icons.person_outline,
            title: 'Compléter mon profil',
            onTap: _navigateToCompleteProfile,
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

  void _navigateToLogin() {
    Navigator.pushNamed(context, Routes.loginRoute);
  }

  void _navigateToSignup() {
    Navigator.pushNamed(context, Routes.registerRoute);
  }

  void _navigateToCompleteProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompleteProfileScreen(
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

  Future<void> _clearLocalAuthData() async {
    try {
      // 1. Supprimer les données d'authentification
      await storage.remove(StockageKeys.tokenKey);
      await storage.remove(StockageKeys.refreshTokenKey);
      await storage.remove(StockageKeys.userKey);
      await storage.remove(StockageKeys.userPreferenceKey);
      await storage.remove(StockageKeys.profileKey);

      await FavoriteDatabaseHelper.instance.clearAllFavorites();
      await ReservationDatabaseHelper.instance.clearAllReservations();

      print("✅ Données d'authentification ET bases de données locales supprimées");
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

    // Afficher un indicateur de chargement
    final scaffold = ScaffoldMessenger.of(context);

    try {
      // 1. Nettoyer les données
      await _clearLocalAuthData();

      // 2. Attendre un cycle de frame pour éviter les conflits
      await Future.delayed(Duration(milliseconds: 100));

      // 3. Navigation sécurisée avec vérification du mounted
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              Routes.bottomPageRoute,
                  (route) => false,
            );
          }
        });
      }

    } catch (e) {
      print("❌ Erreur lors de la déconnexion: $e");

      // Même en cas d'erreur, essayer de naviguer
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            Navigator.pushNamedAndRemoveUntil(
              context,
              Routes.bottomPageRoute,
                  (route) => false,
            );
          } catch (navError) {
            print("❌ Erreur de navigation critique: $navError");

            // Dernière tentative avec un rechargement complet
            if (mounted) {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => HomePage()),
                    (route) => false,
              );
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
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
            _buildSettingsSection(),
            SizedBox(height: 20),
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