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

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _loadSavedData() async {
    final imagePath = storage.read('user_image_path');
    if (imagePath != null) {
      setState(() {
        _imageFile = File(imagePath);
      });
    }
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
    // Remplacer par la logique réelle de comptage des propriétés publiées
    return storage.read('published_properties_count')?.toString() ?? '0';
  }

  String get referralsCount {
    // Remplacer par la logique réelle de comptage des parrainages
    return storage.read('referrals_count')?.toString() ?? '0';
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      await storage.write('user_image_path', pickedFile.path);
    }
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
              icon: Icon(Icons.arrow_back, color: _primaryColor),
              onPressed: () => {},
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
            bio,
            style: TextStyle(
              color: _cardColor.withOpacity(0.9),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
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
            value: safePhone,
          ),
          Divider(height: 24, color: _borderColor),
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Ville',
            value: safeCity,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _primaryColor, size: 20),
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
                  color: _darkColor,
                ),
              ),
            ],
          ),
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

  void _confirmLogout() {
    showDialog(
      context: context,
      barrierDismissible: false, // Empêche la fermeture en cliquant à l'extérieur
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          // Bouton Annuler
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Annuler'),
          ),

          // Bouton Déconnexion
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Ferme la boîte de dialogue

              // Affiche un indicateur de chargement
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
                // 1. Suppression du token
                await storage.remove(StockageKeys.tokenKey);
                // await storage.erase(); // Option: Tout supprimer
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) =>  LoginScreen()),
                      (Route<dynamic> route) => false,
                );

                // 4. Confirmation visuelle
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