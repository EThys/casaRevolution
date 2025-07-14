import 'package:flutter/material.dart';

class TermsAndPrivacyPage extends StatelessWidget {

  final int initialTabIndex;

  TermsAndPrivacyPage({this.initialTabIndex = 0}); // 0 = Conditions, 1 = Confidentialité

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Color(0xFF1976D2);
    final Color darkColor = Color(0xFF1A1D26);
    final Color greyColor = Color(0xFF6C757D);

    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex, // 👈 important
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Conditions & Confidentialité',
            style: TextStyle(
              color: darkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: darkColor),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: greyColor,
            tabs: [
              Tab(text: 'Conditions'),
              Tab(text: 'Confidentialité'),
            ],
          ),
        ),
        body: Container(
          color: Colors.white,
          padding: EdgeInsets.all(20),
          child: TabBarView(
            children: [
              _buildTermsContent(primaryColor, darkColor, greyColor),
              _buildPrivacyContent(primaryColor, darkColor, greyColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsContent(Color primaryColor, Color darkColor, Color greyColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Dernière mise à jour : 14/07/2023', primaryColor),
          SizedBox(height: 24),
          _buildSectionTitle('1. Acceptation des conditions', darkColor),
          _buildSectionText(
            'En utilisant l\'application Yinzo, vous acceptez pleinement et sans réserve les présentes conditions d\'utilisation.',
            greyColor,
          ),
          SizedBox(height: 20),
          _buildSectionTitle('2. Description du service', darkColor),
          _buildSectionText(
            'Yinzo est une plateforme de mise en relation entre propriétaires, locataires et commissionnaires immobiliers pour faciliter les transactions immobilières en RDC.',
            greyColor,
          ),
          SizedBox(height: 20),
          _buildSectionTitle('3. Compte utilisateur', darkColor),
          _buildSectionText(
            'Pour accéder à certaines fonctionnalités, vous devez créer un compte en fournissant des informations exactes et à jour. Vous êtes responsable de la confidentialité de vos identifiants.',
            greyColor,
          ),
          _buildBulletPoint('- Âge minimum requis : 18 ans', greyColor),
          _buildBulletPoint('- Un seul compte par personne', greyColor),
          SizedBox(height: 20),
          _buildSectionTitle('4. Responsabilités', darkColor),
          _buildSectionText(
            'Les utilisateurs sont seuls responsables :',
            greyColor,
          ),
          _buildBulletPoint('Des contenus qu\'ils publient', greyColor),
          _buildBulletPoint('De la véracité des informations fournies', greyColor),
          _buildBulletPoint('Des transactions réalisées en dehors de la plateforme', greyColor),
          SizedBox(height: 20),
          _buildSectionTitle('5. Modifications', darkColor),
          _buildSectionText(
            'Nous nous réservons le droit de modifier ces conditions à tout moment. Les utilisateurs seront notifiés des changements majeurs.',
            greyColor,
          ),
          SizedBox(height: 30),
          _buildContactInfo(primaryColor),
        ],
      ),
    );
  }

  Widget _buildPrivacyContent(Color primaryColor, Color darkColor, Color greyColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Dernière mise à jour : 14/07/2023', primaryColor),
          SizedBox(height: 24),
          _buildSectionTitle('1. Données collectées', darkColor),
          _buildSectionText(
            'Nous collectons les informations suivantes :',
            greyColor,
          ),
          _buildBulletPoint('- Informations de compte (nom, email, téléphone)', greyColor),
          _buildBulletPoint('- Données de profil (photo, localisation)', greyColor),
          _buildBulletPoint('- Documents d\'identité (pour vérification)', greyColor),
          _buildBulletPoint('- Historique d\'activité dans l\'application', greyColor),
          SizedBox(height: 20),
          _buildSectionTitle('2. Utilisation des données', darkColor),
          _buildSectionText(
            'Vos données sont utilisées pour :',
            greyColor,
          ),
          _buildBulletPoint('Fournir et améliorer nos services', greyColor),
          _buildBulletPoint('Vérifier votre identité', greyColor),
          _buildBulletPoint('Personnaliser votre expérience', greyColor),
          _buildBulletPoint('Prévenir les fraudes', greyColor),
          SizedBox(height: 20),
          _buildSectionTitle('3. Partage des données', darkColor),
          _buildSectionText(
            'Nous ne partageons vos informations personnelles qu\'avec :',
            greyColor,
          ),
          _buildBulletPoint('Les utilisateurs concernés par vos transactions', greyColor),
          _buildBulletPoint('Les autorités si requis par la loi', greyColor),
          _buildBulletPoint('Nos prestataires techniques (sous confidentialité)', greyColor),
          SizedBox(height: 20),
          _buildSectionTitle('4. Sécurité', darkColor),
          _buildSectionText(
            'Nous mettons en œuvre des mesures techniques et organisationnelles pour protéger vos données :',
            greyColor,
          ),
          _buildBulletPoint('Chiffrement des données sensibles', greyColor),
          _buildBulletPoint('Accès restreint aux informations', greyColor),
          _buildBulletPoint('Audits de sécurité réguliers', greyColor),
          SizedBox(height: 20),
          _buildSectionTitle('5. Vos droits', darkColor),
          _buildSectionText(
            'Conformément à la loi, vous pouvez :',
            greyColor,
          ),
          _buildBulletPoint('Accéder à vos données personnelles', greyColor),
          _buildBulletPoint('Demander leur rectification', greyColor),
          _buildBulletPoint('Demander leur suppression', greyColor),
          _buildBulletPoint('Vous opposer à leur traitement', greyColor),
          SizedBox(height: 30),
          _buildContactInfo(primaryColor),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildSectionTitle(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSectionText(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: TextStyle(color: color, fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(),
        SizedBox(height: 16),
        Text(
          'Pour toute question concernant nos conditions ou notre politique de confidentialité :',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.email, color: color, size: 20),
            SizedBox(width: 8),
            Text(
              'contact@yinzo.cd',
              style: TextStyle(
                color: color,
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.phone, color: color, size: 20),
            SizedBox(width: 8),
            Text(
              '+243 810 000 000',
              style: TextStyle(
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}