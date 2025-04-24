import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Pour des icônes plus variées

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Hero
            _buildHeroSection(),

            // Section Catégories
            _buildCategorySection(),

            // Section Locations
            _buildSectionHeader(
              title: "Maisons en Location",
              subtitle: "Découvrez nos meilleures offres",
              onSeeAll: () {},
            ),
            _buildPropertyCarousel(isForRent: true),

            // Bannière promotionnelle
            _buildPromoBanner(),

            // Section Ventes
            _buildSectionHeader(
              title: "Maisons en Vente",
              subtitle: "Investissez dans votre avenir",
              onSeeAll: () {},
            ),
            _buildPropertyCarousel(isForRent: false),

            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.menu_rounded, color: Colors.white, size: 30),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'CASA',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 1.0,
              shadows: [
                Shadow(
                  blurRadius: 2.0,
                  color: Colors.black.withOpacity(0.3),
                  offset: Offset(1, 1),
                ),
              ],
          ),
          )
        ],
      ),
      centerTitle: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [darkBlue, primaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
      elevation: 4,
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, size: 28, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: Badge(
            smallSize: 8,
            backgroundColor: Colors.red,
            child: Icon(Icons.notifications_none_rounded, size: 28, color: Colors.white),
          ),
          onPressed: () {},
        ),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 230,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [darkBlue, primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: DrawerHeader(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person_outline_rounded, size: 40, color: primaryColor),
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Bienvenue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Connectez-vous pour plus de fonctionnalités',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.home_filled,
            title: 'Accueil',
            isSelected: true,
          ),
          _buildDrawerItem(
            icon: Icons.favorite_rounded,
            title: 'Favoris',
          ),
          _buildDrawerItem(
            icon: Icons.history_rounded,
            title: 'Historique',
          ),
          _buildDrawerItem(
            icon: Icons.receipt_long_rounded,
            title: 'Mes réservations',
          ),
          Divider(indent: 20, endIndent: 20, thickness: 0.5),
          _buildDrawerItem(
            icon: Icons.settings_rounded,
            title: 'Paramètres',
          ),
          _buildDrawerItem(
            icon: Icons.help_outline_rounded,
            title: 'Aide & Support',
          ),
          _buildDrawerItem(
            icon: Icons.logout_rounded,
            title: 'Déconnexion',
          ),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isSelected ? primaryColor : Colors.grey[700],
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {},
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      height: 220,
      margin: EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [primaryColor, accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 10,
            bottom: 0,
            child: FaIcon(
              FontAwesomeIcons.houseLaptop, // Remplacez par l’icône souhaitée
              size: 150.0,             // Taille en pixels
              color: Colors.red,      // (optionnel) Couleur de l’icône
            )
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trouvez votre\nmaison idéale',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        blurRadius: 2.0,
                        color: Colors.black.withOpacity(0.2),
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Plus de 10,000 propriétés disponibles',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                  ),
                ),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 3,
                    shadowColor: Colors.black.withOpacity(0.2),
                  ),
                  icon: Icon(Icons.search_rounded, size: 20),
                  label: Text(
                    'Commencer la recherche',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    final categories = [
      {'icon': FontAwesomeIcons.building, 'label': 'Appartements'},
      {'icon': FontAwesomeIcons.house, 'label': 'Maisons'},
      {'icon': FontAwesomeIcons.houseChimney, 'label': 'Villas'},
      {'icon': FontAwesomeIcons.buildingColumns, 'label': 'Bureaux'},
      {'icon': FontAwesomeIcons.umbrellaBeach, 'label': 'Vacances'},
      {'icon': FontAwesomeIcons.city, 'label': 'Résidences'},
    ];

    return Container(
      height: 110,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return Container(
            width: 85,
            margin: EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      categories[index]['icon'] as IconData,
                      size: 28,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    categories[index]['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required VoidCallback onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              InkWell(
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'voir',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCarousel({required bool isForRent}) {
    return Container(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: 24, right: 8),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 260,
            margin: EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(20),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                shadowColor: Colors.grey.withOpacity(0.2),
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Image avec overlay
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              image: DecorationImage(
                                image: AssetImage(
                                  isForRent
                                      ? 'assets/images/one.jpg'
                                      : 'assets/images/two.jpg',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        // Overlay gradient pour améliorer la lisibilité
                        Container(
                          height: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20)),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // Bouton favoris
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.favorite_border_rounded,
                              color: primaryColor,
                              size: 22,
                            ),
                          ),
                        ),
                        // Prix en haut à gauche
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              isForRent
                                  ? '${800 + index * 50}€/mois'
                                  : '${250000 + index * 50000}€',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // Badge type (location/vente) en bas à gauche
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isForRent ? accentColor : primaryColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              isForRent ? 'À LOUER' : 'À VENDRE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Section Détails
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Titre et localisation
                          Text(
                            isForRent
                                ? ['Appartement lumineux', 'Studio moderne', 'Loft spacieux', 'Duplex élégant', 'Penthouse luxueux'][index]
                                : ['Maison spacieuse', 'Villa contemporaine', 'Propriété de prestige', 'Maison de campagne', 'Château historique'][index],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: darkBlue,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  isForRent
                                      ? ['Lemba 15ème', 'Ngana 2ème', 'Limete', 'Gombe', 'Msina'][index]
                                      : ['liyolo', 'De la foire', 'Lodja', 'Badara', 'lotambe'][index],
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          // Caractéristiques
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                                bottom: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildFeatureInfo(
                                  icon: FontAwesomeIcons.bed,
                                  value: '${1 + (index % 3)}',
                                ),
                                _buildFeatureInfo(
                                  icon: FontAwesomeIcons.bath,
                                  value: '${1 + (index % 2)}',
                                ),
                                _buildFeatureInfo(
                                  icon: FontAwesomeIcons.rulerCombined,
                                  value: '${40 + index * 20}',

                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Widget _buildFeatureInfo({
  //   required IconData icon,
  //   required String value,
  //   required String label,
  // }) {
  //   return Column(
  //     children: [
  //       Row(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Icon(icon, size: 16, color: primaryColor),
  //           SizedBox(width: 4),
  //           Text(
  //             value,
  //             style: TextStyle(
  //               fontSize: 14,
  //               fontWeight: FontWeight.bold,
  //               color: darkBlue,
  //             ),
  //           ),
  //           if (label == 'm²') SizedBox(width: 0) else SizedBox(width: 4),
  //           if (label != 'm²') Text(
  //             label == 'Chambres' && value == '1' ? 'Chambre' : label,
  //             style: TextStyle(
  //               fontSize: 12,
  //               color: Colors.grey[600],
  //             ),
  //           ),
  //         ],
  //       ),
  //       if (label == 'm²') Text(
  //         label,
  //         style: TextStyle(
  //           fontSize: 12,
  //           color: Colors.grey[600],
  //         ),
  //       ),
  //     ],
  //   );
  // }


  Widget _buildFeatureInfo({required IconData icon, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [darkBlue.withOpacity(0.9), primaryColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_offer_rounded, color: Colors.white, size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offre spéciale avril 2025!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Réduction de 15% sur votre première location avec le code "ETHBERG2025"',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white, size: 30),
        ],
      ),
    );
  }
}