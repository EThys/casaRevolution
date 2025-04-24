import 'package:flutter/material.dart';

class PropertySearchPage extends StatefulWidget {
  @override
  _PropertySearchPageState createState() => _PropertySearchPageState();
}

class _PropertySearchPageState extends State<PropertySearchPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF5F6FA);
  final Color _greyColor = Color(0xFF7F8C8D);

  // Filtres
  RangeValues _priceRange = RangeValues(500, 2500);
  String _selectedPropertyType = 'Tous';
  List<String> _selectedAmenities = [];
  int? _selectedBedrooms;
  int? _selectedBathrooms;
  bool _showFilters = false;

  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _minPriceController.text = _priceRange.start.toInt().toString();
    _maxPriceController.text = _priceRange.end.toInt().toString();
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  // Options de filtre
  String _selectedTransaction = 'Location';
  final List<String> _propertyTypes = [
    'Tous',
    'Appartement',
    'Maison',
    'Studio',
    'Loft',
    'Villa'
  ];

  final List<String> _amenities = [
    'Wifi',
    'Piscine',
    'Parking',
    'Climatisation',
    'Ascenseur',
    'Jardin',
    'Terrasse',
    'Cuisine équipée'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: AppBar(
        title: _buildSearchField(),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: _primaryColor),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: _showFilters ? _buildFullScreenFilterPanel() : _buildPropertyGrid(),
      floatingActionButton: _showFilters ? _buildApplyFiltersButton() : null,
    );
  }

  Widget _buildFullScreenFilterPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(
                    title: 'Type de transaction',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Location', 'Achat'].map((transaction) => FilterChip(
                        label: Text(transaction),
                        selected: _selectedTransaction == transaction,
                        onSelected: (selected) {
                          setState(() {
                            _selectedTransaction = selected ? transaction : 'Location';
                          });
                        },
                        selectedColor: _primaryColor.withOpacity(0.2),
                        backgroundColor: _lightColor,
                        labelStyle: TextStyle(
                          color: _selectedTransaction == transaction ? _primaryColor : _darkColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )).toList(),
                    ),
                  ),
                  Divider(height: 32, thickness: 1, color: Colors.grey[200]),

                  _buildFilterSection(
                    title: 'Type de bien',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _propertyTypes.map((type) => FilterChip(
                        label: Text(type),
                        selected: _selectedPropertyType == type,
                        onSelected: (selected) {
                          setState(() {
                            _selectedPropertyType = selected ? type : 'Tous';
                          });
                        },
                        selectedColor: _primaryColor.withOpacity(0.2),
                        backgroundColor: _lightColor,
                        labelStyle: TextStyle(
                          color: _selectedPropertyType == type ? _primaryColor : _darkColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )).toList(),
                    ),
                  ),
                  Divider(height: 32, thickness: 1, color: Colors.grey[200]),
                  _buildPriceFilterSection(),
                  Divider(height: 32, thickness: 1, color: Colors.grey[200]),

                  _buildFilterSection(
                    title: 'Nombre de pièces',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(5, (index) {
                        final roomCount = index + 1;
                        return ChoiceChip(
                          label: Text(roomCount == 5 ? '5+' : '$roomCount'),
                          selected: _selectedBedrooms == roomCount,
                          onSelected: (selected) {
                            setState(() {
                              _selectedBedrooms = selected ? roomCount : null;
                            });
                          },
                          selectedColor: _primaryColor,
                          backgroundColor: _lightColor,
                          labelStyle: TextStyle(
                            color: _selectedBedrooms == roomCount ? Colors.white : _darkColor,
                          ),
                          shape: StadiumBorder(),
                        );
                      }),
                    ),
                  ),
                  Divider(height: 32, thickness: 1, color: Colors.grey[200]),

                  _buildFilterSection(
                    title: 'Salles de bain',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(4, (index) {
                        final bathroomCount = index + 1;
                        return ChoiceChip(
                          label: Text(bathroomCount == 4 ? '4+' : '$bathroomCount'),
                          selected: _selectedBathrooms == bathroomCount,
                          onSelected: (selected) {
                            setState(() {
                              _selectedBathrooms = selected ? bathroomCount : null;
                            });
                          },
                          selectedColor: _primaryColor,
                          backgroundColor: _lightColor,
                          labelStyle: TextStyle(
                            color: _selectedBathrooms == bathroomCount ? Colors.white : _darkColor,
                          ),
                          shape: StadiumBorder(),
                        );
                      }),
                    ),
                  ),
                  Divider(height: 32, thickness: 1, color: Colors.grey[200]),

                  _buildFilterSection(
                    title: 'Équipements',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _amenities.map((amenity) => FilterChip(
                        label: Text(amenity),
                        selected: _selectedAmenities.contains(amenity),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedAmenities.add(amenity);
                            } else {
                              _selectedAmenities.remove(amenity);
                            }
                          });
                        },
                        selectedColor: _primaryColor.withOpacity(0.2),
                        backgroundColor: _lightColor,
                        labelStyle: TextStyle(
                          color: _selectedAmenities.contains(amenity) ? _primaryColor : _darkColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )).toList(),
                    ),
                  ),
                  SizedBox(height: 80), // Espace pour le bouton flottant
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPriceFilterSection() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _selectedTransaction == 'Location' ? 'Prix (\$/mois)' : 'Prix',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _darkColor,
            ),
          ),
        ),
        RangeSlider(
          values: _priceRange,
          min: 20,
          max: 5000,
          divisions: (5000 - 20) ~/ 20, // Pas de 20
          labels: RangeLabels(
            '${_priceRange.start.toInt()}\$',
            '${_priceRange.end.toInt()}\$',
          ),
          onChanged: (RangeValues values) {
            setState(() {
              _priceRange = values;
              _minPriceController.text = values.start.toInt().toString();
              _maxPriceController.text = values.end.toInt().toString();
            });
          },
          activeColor: _primaryColor,
          inactiveColor: _greyColor.withOpacity(0.3),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildPriceInputField(
                controller: _minPriceController,
                label: 'Min',
                onChanged: (value) {
                  final newMin = int.tryParse(value) ?? 20;
                  setState(() {
                    _priceRange = RangeValues(
                      newMin.clamp(20, _priceRange.end).toDouble(),
                      _priceRange.end,
                    );
                  });
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildPriceInputField(
                controller: _maxPriceController,
                label: 'Max',
                onChanged: (value) {
                  final newMax = int.tryParse(value) ?? 5000;
                  setState(() {
                    _priceRange = RangeValues(
                      _priceRange.start,
                      newMax.clamp(_priceRange.start, 5000).toDouble(),
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceInputField({
    required TextEditingController controller,
    required String label,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixText: '\$ ',
        suffixText: _selectedTransaction == 'Location' ? '/mois' : null,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      keyboardType: TextInputType.number,
      style: TextStyle(fontSize: 14),
      onChanged: onChanged,
    );
  }

  // ... (le reste du code reste identique jusqu'à la méthode buildFilterSection)

  Widget _buildFilterSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 12),
        child,
      ],
    );
  }





  Widget _buildPropertyGrid() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPropertyCard(index),
              childCount: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      margin: EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: _lightColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Rechercher par ville, quartier...',
          prefixIcon: Icon(Icons.search_rounded, color: _greyColor),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  // Widget _buildFilterSection({required String title, required Widget child}) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         title,
  //         style: TextStyle(
  //           fontSize: 16,
  //           fontWeight: FontWeight.bold,
  //           color: _darkColor,
  //         ),
  //       ),
  //       SizedBox(height: 12),
  //       child,
  //     ],
  //   );
  // }

  Widget _buildPropertyCard(int index) {
    // Liste de vos images assets
    final List<String> propertyImages = [
      'assets/images/one.jpg',
      'assets/images/two.jpg',
      'assets/images/three.jpg',
    ];

    // Utilisation modulo pour cycler à travers les images si vous avez plus de cartes que d'images
    final imageIndex = index % propertyImages.length;

    return GestureDetector(
      onTap: () {
        // Naviguer vers la page de détails
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
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
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    // Remplacement de l'icône par une image asset
                    Image.asset(
                      propertyImages[imageIndex],
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Icon(Icons.home_rounded, size: 40, color: Colors.grey[400]),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: IconButton(
                        icon: Icon(
                          Icons.favorite_border_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () {},
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Text(
                        '${800 + index * 200}\$/mois',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appartement moderne ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _darkColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: _greyColor),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Paris, ${index + 1}ème arrondissement',
                          style: TextStyle(
                            color: _greyColor,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.king_bed_rounded, size: 14, color: _greyColor),
                      SizedBox(width: 4),
                      Text(
                        '${index % 3 + 1} ch.',
                        style: TextStyle(
                          color: _greyColor,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.bathtub_rounded, size: 14, color: _greyColor),
                      SizedBox(width: 4),
                      Text(
                        '${index % 2 + 1} sdb',
                        style: TextStyle(
                          color: _greyColor,
                          fontSize: 12,
                        ),
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

  Widget _buildApplyFiltersButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        setState(() {
          _showFilters = false;
        });
        // Appliquer les filtres ici
      },
      icon: Icon(Icons.check_rounded),
      label: Text('Appliquer',style: TextStyle(color: Colors.white),),
      backgroundColor: _primaryColor,
      elevation: 4,
    );
  }
}