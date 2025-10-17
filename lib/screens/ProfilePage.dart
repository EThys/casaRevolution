import 'package:casa/screens/BottomNavBar.dart';
import 'package:casa/screens/auth/LoginScreen.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../utils/Routes.dart';

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

    final userData = storage.read(StockageKeys.userKey) ?? {};

    if (userData['username']?.toString().isNotEmpty == true) completedFields++;
    if (userData['email']?.toString().isNotEmpty == true) completedFields++;
    if (userData['phone']?.toString().isNotEmpty == true) completedFields++;
    if (userData['city']?.toString().isNotEmpty == true) completedFields++;
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
    return storage.read(StockageKeys.userKey)?['username']?.toString() ?? 'Visiteur';
  }

  String get safeEmail {
    return storage.read(StockageKeys.userKey)?['email']?.toString() ?? 'Non connecté';
  }

  String get safePhone {
    return storage.read(StockageKeys.userKey)?['phone']?.toString() ?? '';
  }

  String get safeCity {
    return storage.read(StockageKeys.userKey)?['city']?.toString() ?? '';
  }

  String get bio {
    return storage.read(StockageKeys.userKey)?['bio']?.toString() ?? '';
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
    final userData = storage.read(StockageKeys.userKey) ?? {};
    List<String> missingFields = [];

    if (userData['phone']?.toString().isEmpty == true) missingFields.add('téléphone');
    if (userData['city']?.toString().isEmpty == true) missingFields.add('ville');
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
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: _cardColor),
              onPressed: () => Navigator.pop(context),
            ),
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
            label: 'Ville',
            value: safeCity.isNotEmpty ? safeCity : 'Non renseignée',
            isComplete: safeCity.isNotEmpty,
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
              onPressed: _navigateToLogin,
              color: _primaryColor,
            ),
            SizedBox(height: 12),
            _buildAuthButton(
              text: 'Créer un compte',
              onPressed: _navigateToSignup,
              color: _successColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuthButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
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
            onPressed: () async {
              Navigator.pop(context);
              final scaffold = ScaffoldMessenger.of(context);
              scaffold.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Text('Déconnexion en cours...'),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );

              try {
                await storage.erase();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                      (Route<dynamic> route) => false,
                );

                scaffold.showSnackBar(
                  const SnackBar(
                    content: Text('Déconnexion réussie'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                scaffold.showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de la déconnexion: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
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

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final GetStorage storage = GetStorage();
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF64B5F6);
  final Color _darkColor = Color(0xFF2D3748);
  final Color _lightColor = Color(0xFFF7FAFC);
  final Color _greyColor = Color(0xFF718096);
  final Color _successColor = Color(0xFF48BB78);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFE2E8F0);

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  void _loadCurrentData() {
    final userData = storage.read(StockageKeys.userKey) ?? {};
    setState(() {
      _phoneController.text = userData['phone']?.toString() ?? '';
      _cityController.text = userData['city']?.toString() ?? '';
      _bioController.text = userData['bio']?.toString() ?? '';
    });

    final imagePath = storage.read('user_image_path');
    if (imagePath != null) {
      setState(() {
        _imageFile = File(imagePath);
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    final currentUserData = storage.read(StockageKeys.userKey) ?? {};

    final updatedUserData = {
      ...currentUserData,
      'phone': _phoneController.text,
      'city': _cityController.text,
      'bio': _bioController.text,
    };

    await storage.write(StockageKeys.userKey, updatedUserData);

    if (_imageFile != null) {
      await storage.write('user_image_path', _imageFile!.path);
    }

    widget.onProfileUpdated();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profil mis à jour avec succès'),
        backgroundColor: _successColor,
      ),
    );

    Navigator.pop(context);
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(top: 60, bottom: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_primaryColor, _secondaryColor],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Complétez votre profil',
            style: TextStyle(
              color: _cardColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ajoutez vos informations pour personnaliser votre expérience',
            style: TextStyle(
              color: _cardColor.withOpacity(0.9),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt_outlined, color: _primaryColor, size: 20),
              SizedBox(width: 12),
              Text(
                'Photo de profil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _borderColor, width: 2),
              ),
              child: ClipOval(
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : Container(
                  color: _lightColor,
                  child: Icon(
                    Icons.person_add,
                    size: 40,
                    color: _greyColor,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Cliquez pour ajouter une photo',
            style: TextStyle(
              fontSize: 12,
              color: _greyColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      child: Column(
        children: [
          _buildFormField(
            icon: Icons.phone_outlined,
            label: 'Numéro de téléphone',
            controller: _phoneController,
            hintText: 'Entrez votre numéro',
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: 16),
          _buildFormField(
            icon: Icons.location_on_outlined,
            label: 'Ville',
            controller: _cityController,
            hintText: 'Entrez votre ville',
          ),
          SizedBox(height: 16),
          _buildFormField(
            icon: Icons.description_outlined,
            label: 'Bio',
            controller: _bioController,
            hintText: 'Décrivez-vous en quelques mots...',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _primaryColor, size: 20),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _darkColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Enregistrer les modifications',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildPhotoSection(),
            _buildFormSection(),
            _buildSaveButton(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}