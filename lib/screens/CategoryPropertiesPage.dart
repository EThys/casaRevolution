import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CategoryPropertiesPage extends StatefulWidget {
  final String categoryName;
  final IconData categoryIcon;

  const CategoryPropertiesPage({
    Key? key,
    required this.categoryName,
    required this.categoryIcon,
  }) : super(key: key);

  @override
  _CategoryPropertiesPageState createState() => _CategoryPropertiesPageState();
}

class _CategoryPropertiesPageState extends State<CategoryPropertiesPage> {
  final Color primaryColor = Color(0xFF1976D2);
  final Color accentColor = Color(0xFF64B5F6);
  final Color darkBlue = Color(0xFF0D47A1);

  // Filtres
  String _selectedFilter = 'Tout';
  bool _isForRent = true;
  int _priceRange = 0;
  int _bedrooms = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Section de filtres
          _buildFilterSection(),

          // Liste des propriétés
          Expanded(
            child: _buildPropertyList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Icon(widget.categoryIcon, color: Colors.white, size: 24),
          SizedBox(width: 10),
          Text(
            widget.categoryName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      centerTitle: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [darkBlue, primaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.filter_list_rounded, color: Colors.white),
          onPressed: _showFilterDialog,
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    final filters = ['Tout', 'Populaire', 'Nouveau', 'Prix bas', 'Prix haut'];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
      BoxShadow(
      color: Colors.grey.withOpacity(0.1),
      spreadRadius: 1,
      blurRadius: 5,
      offset: Offset(0, 2),
      )
      ],
    ),
    child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
    children: filters.map((filter) {
    bool isSelected = _selectedFilter == filter;
    return Padding(
    padding: const EdgeInsets.only(right: 8.0),
    child: ChoiceChip(
    label: Text(filter),
    selected: isSelected,
    onSelected: (selected) {
    setState(() {
    _selectedFilter = selected ? filter : 'Tout';
    });
    },
    selectedColor: primaryColor.withOpacity(0.2),
    backgroundColor: Colors.grey[100],
    labelStyle: TextStyle(
    color: isSelected ? primaryColor : Colors.grey[700],
    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
    ),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
    ),
    ),
    );
    }).toList(),
    ),
    ),
    );
  }

  Widget _buildPropertyList() {
    // Données simulées basées sur la catégorie
    List<Map<String, dynamic>> properties = _getPropertiesByCategory(widget.categoryName);

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final property = properties[index];
        return _buildPropertyCard(property);
      },
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Naviguer vers la page de détails
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image avec badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    property['image'],
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: Icon(
                      property['isFavorite'] ? Icons.favorite : Icons.favorite_border,
                      color: property['isFavorite'] ? Colors.red : Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        property['isFavorite'] = !property['isFavorite'];
                      });
                    },
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: property['forRent'] ? accentColor : primaryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      property['forRent'] ? 'À LOUER' : 'À VENDRE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Détails de la propriété
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        property['title'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                      Text(
                        property['forRent']
                            ? '${property['price']}€/mois'
                            : '${property['price']}€',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        property['location'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  // Caractéristiques
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPropertyFeature(
                        icon: FontAwesomeIcons.bed,
                        value: '${property['bedrooms']}',
                        label: property['bedrooms'] > 1 ? 'Chambres' : 'Chambre',
                      ),
                      _buildPropertyFeature(
                        icon: FontAwesomeIcons.bath,
                        value: '${property['bathrooms']}',
                        label: 'Salles de bain',
                      ),
                      _buildPropertyFeature(
                        icon: FontAwesomeIcons.rulerCombined,
                        value: '${property['area']}',
                        label: 'm²',
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


  Widget _buildPropertyFeature({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filtrer',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  Divider(),

                  // Type de transaction
                  Text(
                    'Type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text('À louer'),
                          selected: _isForRent,
                          onSelected: (selected) {
                            setModalState(() {
                              _isForRent = true;
                            });
                          },
                          selectedColor: primaryColor,
                          labelStyle: TextStyle(
                            color: _isForRent ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: Text('À vendre'),
                          selected: !_isForRent,
                          onSelected: (selected) {
                            setModalState(() {
                              _isForRent = false;
                            });
                          },
                          selectedColor: primaryColor,
                          labelStyle: TextStyle(
                            color: !_isForRent ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Fourchette de prix
                  Text(
                    'Fourchette de prix',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Slider(
                    value: _priceRange.toDouble(),
                    min: 0,
                    max: 4,
                    divisions: 4,
                    label: _getPriceRangeLabel(_priceRange),
                    onChanged: (value) {
                      setModalState(() {
                        _priceRange = value.toInt();
                      });
                    },
                    activeColor: primaryColor,
                  ),

                  SizedBox(height: 20),

                  // Nombre de chambres
                  Text(
                    'Chambres',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Slider(
                    value: _bedrooms.toDouble(),
                    min: 0,
                    max: 5,
                    divisions: 5,
                    label: _bedrooms == 0 ? 'Tout' : '${_bedrooms}+',
                    onChanged: (value) {
                      setModalState(() {
                        _bedrooms = value.toInt();
                      });
                    },
                    activeColor: primaryColor,
                  ),

                  Spacer(),

                  // Boutons d'action
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _isForRent = true;
                              _priceRange = 0;
                              _bedrooms = 0;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: primaryColor),
                          ),
                          child: Text(
                            'Réinitialiser',
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // Appliquer les filtres
                            setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Appliquer',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getPriceRangeLabel(int range) {
    if (_isForRent) {
      switch (range) {
        case 0: return 'Tout prix';
        case 1: return '< 500€';
        case 2: return '500-1000€';
        case 3: return '1000-2000€';
        case 4: return '> 2000€';
        default: return 'Tout prix';
      }
    } else {
      switch (range) {
        case 0: return 'Tout prix';
        case 1: return '< 200K€';
        case 2: return '200-500K€';
        case 3: return '500K-1M€';
        case 4: return '> 1M€';
        default: return 'Tout prix';
      }
    }
  }

  List<Map<String, dynamic>> _getPropertiesByCategory(String category) {
    // Données simulées en fonction de la catégorie
    if (category == 'Appartements') {
      return [
        {
          'title': 'Appartement lumineux Paris 15ème',
          'location': 'Paris 15ème, France',
          'price': 850,
          'bedrooms': 2,
          'bathrooms': 1,
          'area': 45,
          'forRent': true,
          'isFavorite': false,
          'image': 'https://source.unsplash.com/random/600x400/?apartment,1',
        },
        {
          'title': 'Studio moderne Lyon 2ème',
          'location': 'Lyon 2ème, France',
          'price': 650,
          'bedrooms': 1,
          'bathrooms': 1,
          'area': 30,
          'forRent': true,
          'isFavorite': true,
          'image': 'https://source.unsplash.com/random/600x400/?apartment,2',
        },
        {
          'title': 'Appartement avec terrasse',
          'location': 'Marseille, France',
          'price': 950,
          'bedrooms': 3,
          'bathrooms': 2,
          'area': 65,
          'forRent': true,
          'isFavorite': false,
          'image': 'https://source.unsplash.com/random/600x400/?apartment,3',
        },
        {
          'title': 'Appartement neuf à vendre',
          'location': 'Bordeaux, France',
          'price': 320000,
          'bedrooms': 2,
          'bathrooms': 1,
          'area': 55,
          'forRent': false,
          'isFavorite': false,
          'image': 'https://source.unsplash.com/random/600x400/?apartment,4',
        },
      ];
    } else if (category == 'Maisons') {
      return [
        {
          'title': 'Maison spacieuse avec jardin',
          'location': 'Neuilly-sur-Seine, France',
          'price': 450000,
          'bedrooms': 4,
          'bathrooms': 2,
          'area': 120,
          'forRent': false,
          'isFavorite': false,
          'image': 'https://source.unsplash.com/random/600x400/?house,1',
        },
        {
          'title': 'Maison de ville à louer',
          'location': 'Versailles, France',
          'price': 1800,
          'bedrooms': 3,
          'bathrooms': 2,
          'area': 95,
          'forRent': true,
          'isFavorite': true,
          'image': 'https://source.unsplash.com/random/600x400/?house,2',
        },
      ];
    } else if (category == 'Villas') {
      return [
        {
          'title': 'Villa contemporaine',
          'location': 'Saint-Tropez, France',
          'price': 1200000,
          'bedrooms': 5,
          'bathrooms': 3,
          'area': 200,
          'forRent': false,
          'isFavorite': false,
          'image': 'https://source.unsplash.com/random/600x400/?villa,1',
        },
        {
          'title': 'Villa avec piscine',
          'location': 'Cannes, France',
          'price': 8500,
          'bedrooms': 6,
          'bathrooms': 4,
          'area': 250,
          'forRent': true,
          'isFavorite': true,
          'image': 'https://source.unsplash.com/random/600x400/?villa,2',
        },
      ];
    }

    // Retour par défaut
    return [
      {
        'title': 'Propriété ${widget.categoryName.toLowerCase()}',
        'location': 'France',
        'price': 1000,
        'bedrooms': 2,
        'bathrooms': 1,
        'area': 60,
        'forRent': true,
        'isFavorite': false,
        'image': 'https://source.unsplash.com/random/600x400/?home',
      },
    ];
  }
}