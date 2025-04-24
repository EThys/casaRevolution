import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final List<FavoriteProperty> _favorites = [];
  final DateFormat _dateFormat = DateFormat('EEEE d MMMM y', 'fr_FR');

  // Couleurs modernes (reprises de la page des réservations)

  final Color _primaryColor = Color(0xFF1976D2);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightGrey = Color(0xFFF5F6FA);
  final Color _mediumGrey = Color(0xFF7F8C8D);
  final Color _successColor = Color(0xFF00B894);
  final Color _errorColor = Color(0xFFD63031);
  final Color _cardBackground = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    setState(() {
      _favorites.addAll([
      FavoriteProperty(
      id: '1',
      title: 'Appartement lumineux avec vue sur la tour Eiffel',
      image: 'assets/images/one.jpg',
      address: '15 Rue de Rivoli, 75004 Paris',
      price: 1200,
      features: '2 chambres · 75m² · 3ème étage',
      addedDate: DateTime.now().subtract(Duration(days: 2)),
      ),
      FavoriteProperty(
      id: '2',
      title: 'Studio design en hypercentre',
      image:  'assets/images/three.jpg',
      address: '18 rue, 75001 Limete',
      price: 850,
      features: '1 chambre · 35m² · Rez-de-chaussée',
      addedDate: DateTime.now().subtract(Duration(days: 5)),
      isAvailable: false,
      ),
      FavoriteProperty(
      id: '3',
      title: 'Duplex loft dans le Marais',
      image: 'assets/images/one.jpg',
      address: '4 Rue du livre, 75004 Gombe',
      price: 1500,
      features: '3 chambres · 110m² · 2ème étage',
      addedDate: DateTime.now().subtract(Duration(days: 10)),
      ),
      FavoriteProperty(
      id: '4',
      title: 'Appartement haussmannien rénové',
      image: 'assets/images/two.jpg',
      address: '12 Avenue de l\'Opéra, 75002 Paris',
      price: 1800,
      features: '2 chambres · 90m² · 4ème étage',
      addedDate: DateTime.now().subtract(Duration(days: 15)),
      ),
      FavoriteProperty(
      id: '5',
      title: 'Maison avec jardin arboré',
      image:  'assets/images/one.two',
      address: '5 Rue des Jardins, 75016 Paris',
      price: 2500,
      features: '4 chambres · 150m² · Jardin 50m²',
      addedDate: DateTime.now().subtract(Duration(days: 30)),
      isAvailable: false,
      ),
      ]);
    });
  }

  void _removeFavorite(String id) {
    setState(() {
      _favorites.removeWhere((fav) => fav.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Supprimé des favoris'),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showPropertyDetails(FavoriteProperty property) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPropertyDetails(property),
    );
  }

  Widget _buildPropertyDetails(FavoriteProperty property) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Détails du bien',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    property.image,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: _lightGrey,
                      child: Center(
                        child: Icon(Icons.home, size: 50, color: _mediumGrey),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  property.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: _mediumGrey),
                    SizedBox(width: 4),
                    Text(
                      property.address,
                      style: TextStyle(
                        color: _mediumGrey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Divider(height: 1, color: Colors.grey[200]),
                SizedBox(height: 15),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.euro_symbol_outlined,
                        size: 20,
                        color: _primaryColor,
                      ),
                    ),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prix',
                          style: TextStyle(
                            color: _mediumGrey,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${property.price}\$/mois',
                          style: TextStyle(
                            color: _darkColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: property.isAvailable
                            ? _successColor.withOpacity(0.1)
                            : _errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        property.isAvailable ? 'Disponible' : 'Indisponible',
                        style: TextStyle(
                          color: property.isAvailable ? _successColor : _errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Divider(height: 1, color: Colors.grey[200]),
                SizedBox(height: 15),
                Text(
                  'Caractéristiques',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  property.features,
                  style: TextStyle(
                    color: _darkColor.withOpacity(0.8),
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _removeFavorite(property.id);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _errorColor,
                          side: BorderSide(color: _errorColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'SUPPRIMER DES FAVORIS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Action pour contacter le propriétaire
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'CONTACTER',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGrey,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mes Favoris',
          style: TextStyle(
            color: _darkColor,
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: _darkColor),
            onPressed: () {
              // Action de recherche
            },
          ),
        ],
      ),
      body: _buildFavoritesList(),
    );
  }

  Widget _buildFavoritesList() {
    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border_outlined,
              size: 60,
              color: _mediumGrey.withOpacity(0.3),
            ),
            SizedBox(height: 20),
            Text(
              'Aucun favori',
              style: TextStyle(
                color: _mediumGrey,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Ajoutez des propriétés à vos favoris pour les retrouver facilement',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _mediumGrey.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Action pour explorer les propriétés
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              ),
              child: Text(
                'Explorer les propriétés',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: () async {
        await Future.delayed(Duration(seconds: 1));
        _loadFavorites();
      },
      child: ListView.separated(
        padding: EdgeInsets.all(20),
        itemCount: _favorites.length,
        separatorBuilder: (_, __) => SizedBox(height: 20),
        itemBuilder: (context, index) {
          return _buildFavoriteCard(_favorites[index]);
        },
      ),
    );
  }

  Widget _buildFavoriteCard(FavoriteProperty property) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showPropertyDetails(property),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _cardBackground,
            boxShadow: [
              BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: 1,
              offset: Offset(0, 10),
              )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.asset(
                  property.image,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // loadingBuilder: (context, child, loadingProgress) {
                  //   if (loadingProgress == null) return child;
                  //   return Container(
                  //     height: 180,
                  //     color: _lightGrey,
                  //     child: Center(
                  //       child: CircularProgressIndicator(
                  //         color: _primaryColor,
                  //         strokeWidth: 2,
                  //       ),
                  //     ),
                  //   );
                  // },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: _lightGrey,
                    child: Center(
                      child: Icon(
                        Icons.home_outlined,
                        size: 40,
                        color: _mediumGrey.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 15,
                right: 15,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '${property.price}\$/mois',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (!property.isAvailable)
                Positioned(
                  bottom: 15,
                  left: 15,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _errorColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'INDISPONIBLE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _darkColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: _mediumGrey,
                    ),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        property.address,
                        style: TextStyle(
                          color: _mediumGrey,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 18,
                      color: _primaryColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Ajouté le ${_dateFormat.format(property.addedDate)}',
                      style: TextStyle(
                        color: _mediumGrey,
                        fontSize: 13,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: _errorColor),
                      onPressed: () => _removeFavorite(property.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class FavoriteProperty {
  final String id;
  final String title;
  final String image;
  final String address;
  final int price;
  final String features;
  final DateTime addedDate;
  bool isAvailable;

  FavoriteProperty({
    required this.id,
    required this.title,
    required this.image,
    required this.address,
    required this.price,
    required this.features,
    required this.addedDate,
    this.isAvailable = true,
  });
}