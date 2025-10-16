import 'package:flutter/material.dart';

class PropertySearchPage extends StatefulWidget {
  @override
  _PropertySearchPageState createState() => _PropertySearchPageState();
}

class _PropertySearchPageState extends State<PropertySearchPage> {
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _darkColor = Color(0xFF1A1D26);
  final Color _lightColor = Color(0xFFF5F6FA);
  final Color _greyColor = Color(0xFF7F8C8D);
  final Color _accentColor = Color(0xFF4CAF50);

  // Filtres
  RangeValues _priceRange = RangeValues(500, 2500);
  String _selectedPropertyType = 'Tous';
  String? _selectedBedrooms;
  bool _showFilters = false;

  // Nouveaux contrôles
  String? _selectedCity;
  String? _selectedCommune;
  TextEditingController _minPriceController = TextEditingController();
  TextEditingController _maxPriceController = TextEditingController();
  TextEditingController _bedroomsController = TextEditingController();
  FocusNode _minPriceFocus = FocusNode();
  FocusNode _maxPriceFocus = FocusNode();
  FocusNode _bedroomsFocus = FocusNode();

  // Options
  String _selectedTransaction = 'Location';
  final List<String> _propertyTypes = ['Tous', 'Appartement', 'Maison', 'Studio'];
  final List<String> _cities = ['Paris', 'Lyon', 'Marseille', 'Toulouse', 'Nice', 'Nantes'];
  final List<String> _communes = [
    '1er arrondissement', '2ème arrondissement', '3ème arrondissement',
    '4ème arrondissement', '5ème arrondissement', '6ème arrondissement'
  ];

  @override
  void initState() {
    super.initState();
    _minPriceController.text = _priceRange.start.toInt().toString();
    _maxPriceController.text = _priceRange.end.toInt().toString();

    // Listeners pour synchroniser les prix
    _minPriceController.addListener(_updatePriceRange);
    _maxPriceController.addListener(_updatePriceRange);
  }

  void _updatePriceRange() {
    final min = int.tryParse(_minPriceController.text) ?? 500;
    final max = int.tryParse(_maxPriceController.text) ?? 2500;
    if (min <= max) {
      setState(() {
        _priceRange = RangeValues(min.toDouble(), max.toDouble());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: _showFilters ? null : _buildAppBar(),
      body: _showFilters ? _buildSimplifiedFilterPanel() : _buildPropertyList(),
      floatingActionButton: _showFilters ? _buildApplyFiltersButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: _buildSearchField(),
      centerTitle: false,
      elevation: 1,
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      actions: [
        _buildFilterBadge(),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFilterBadge() {
    final filterCount = _getActiveFilterCount();

    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.filter_list_rounded, color: _primaryColor),
          onPressed: () {
            setState(() {
              _showFilters = true;
            });
          },
        ),
        if (filterCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _accentColor,
                shape: BoxShape.circle,
              ),
              constraints: BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                filterCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedPropertyType != 'Tous') count++;
    if (_selectedBedrooms != null && _selectedBedrooms!.isNotEmpty) count++;
    if (_priceRange.start > 500 || _priceRange.end < 2500) count++;
    if (_selectedCity != null) count++;
    if (_selectedCommune != null) count++;
    return count;
  }

  Widget _buildSimplifiedFilterPanel() {
    return GestureDetector(
      onTap: () {
        // Fermer le clavier quand on tape ailleurs
        FocusScope.of(context).unfocus();
      },
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // En-tête des filtres
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: _darkColor),
                    onPressed: () {
                      setState(() {
                        _showFilters = false;
                      });
                    },
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Filtres',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _darkColor,
                    ),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: _resetFilters,
                    child: Text(
                      'Réinitialiser',
                      style: TextStyle(color: _primaryColor),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTransactionTypeSection(),
                    SizedBox(height: 24),
                    _buildLocationSection(),
                    SizedBox(height: 24),
                    _buildPropertyTypeSection(),
                    SizedBox(height: 24),
                    _buildPriceFilterSection(),
                    SizedBox(height: 24),
                    _buildBedroomsSection(),
                    SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de transaction',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTransactionOption('Location', Icons.home_work_outlined),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              Expanded(
                child: _buildTransactionOption('Achat', Icons.shopping_cart_outlined),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Localisation',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 16),
        _buildDropdownField(
          'Ville',
          _selectedCity,
          _cities,
          Icons.location_city,
              (value) {
            setState(() {
              _selectedCity = value;
            });
          },
        ),
        SizedBox(height: 16),
        _buildDropdownField(
          'Commune',
          _selectedCommune,
          _communes,
          Icons.map,
              (value) {
            setState(() {
              _selectedCommune = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDropdownField(
      String hint,
      String? value,
      List<String> items,
      IconData icon,
      ValueChanged<String?> onChanged,
      ) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _lightColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: _greyColor),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text('Sélectionner $hint', style: TextStyle(color: _greyColor)),
          ),
          ...items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: TextStyle(color: _darkColor)),
          )),
        ],
        onChanged: onChanged,
        icon: Icon(Icons.arrow_drop_down_rounded, color: _primaryColor),
        dropdownColor: Colors.white,
        style: TextStyle(fontSize: 14, color: _darkColor),
      ),
    );
  }

  Widget _buildTransactionOption(String type, IconData icon) {
    final isSelected = _selectedTransaction == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTransaction = type;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: type == 'Location'
              ? BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12))
              : BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color: isSelected ? _primaryColor : _greyColor),
            SizedBox(height: 4),
            Text(
              type,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? _primaryColor : _greyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de bien',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _propertyTypes.map((type) => _buildPropertyTypeChip(type)).toList(),
        ),
      ],
    );
  }

  Widget _buildPropertyTypeChip(String type) {
    final isSelected = _selectedPropertyType == type;
    final icon = _getPropertyTypeIcon(type);

    return FilterChip(
      label: Text(type),
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : _primaryColor),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPropertyType = selected ? type : 'Tous';
        });
      },
      selectedColor: _primaryColor,
      backgroundColor: _lightColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : _darkColor,
        fontSize: 13,
      ),
      shape: StadiumBorder(
        side: BorderSide(color: isSelected ? _primaryColor : Colors.grey[300]!),
      ),
    );
  }

  IconData _getPropertyTypeIcon(String type) {
    switch (type) {
      case 'Appartement':
        return Icons.apartment;
      case 'Maison':
        return Icons.house;
      case 'Studio':
        return Icons.weekend;
      default:
        return Icons.category;
    }
  }

  Widget _buildPriceFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prix (\$)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildPriceInputField(
                'Prix min',
                _minPriceController,
                _minPriceFocus,
                Icons.arrow_downward_rounded,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildPriceInputField(
                'Prix max',
                _maxPriceController,
                _maxPriceFocus,
                Icons.arrow_upward_rounded,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        RangeSlider(
          values: _priceRange,
          min: 20,
          max: 5000,
          divisions: 100,
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
          inactiveColor: Colors.grey[300],
        ),
      ],
    );
  }

  Widget _buildPriceInputField(
      String hint,
      TextEditingController controller,
      FocusNode focusNode,
      IconData icon,
      ) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _lightColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: _greyColor, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          suffixText: '\$',
          suffixStyle: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
        ),
        style: TextStyle(fontSize: 14, color: _darkColor),
        onChanged: (value) {
          _updatePriceRange();
        },
      ),
    );
  }

  Widget _buildBedroomsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nombre de chambres',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _darkColor,
          ),
        ),
        SizedBox(height: 16),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: _lightColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: _bedroomsController,
            focusNode: _bedroomsFocus,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Ex: 3',
              prefixIcon: Icon(Icons.king_bed_rounded, color: _greyColor),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              suffixIcon: IconButton(
                icon: Icon(Icons.clear_rounded, color: _greyColor, size: 18),
                onPressed: () {
                  setState(() {
                    _bedroomsController.clear();
                    _selectedBedrooms = null;
                  });
                },
              ),
            ),
            style: TextStyle(fontSize: 14, color: _darkColor),
            onChanged: (value) {
              setState(() {
                _selectedBedrooms = value.isNotEmpty ? value : null;
              });
            },
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [1, 2, 3, 4, 5].map((count) => _buildQuickBedroomChip(count)).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickBedroomChip(int count) {
    final isSelected = _bedroomsController.text == count.toString();
    final label = count == 5 ? '5+' : '$count';

    return GestureDetector(
      onTap: () {
        setState(() {
          _bedroomsController.text = count.toString();
          _selectedBedrooms = count.toString();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : _lightColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.king_bed_rounded,
                size: 14,
                color: isSelected ? Colors.white : _greyColor),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : _darkColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) => _buildPropertyListItem(index),
    );
  }

  Widget _buildPropertyListItem(int index) {
    final propertyImages = [
      'assets/images/one.jpg',
      'assets/images/two.jpg',
      'assets/images/three.jpg',
    ];
    final imageIndex = index % propertyImages.length;
    final price = 800 + index * 200;
    final bedrooms = index % 3 + 1;
    final bathrooms = index % 2 + 1;
    final surface = 70 + index * 10;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            width: 120,
            height: 120,
            margin: EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                propertyImages[imageIndex],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.home_rounded, size: 32, color: Colors.grey[400]),
                  );
                },
              ),
            ),
          ),

          // Détails
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 12, right: 12, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _propertyTypes[(index % (_propertyTypes.length - 1)) + 1],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.favorite_border_rounded, size: 20, color: _greyColor),
                    ],
                  ),

                  SizedBox(height: 8),
                  Text(
                    'Appartement moderne ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),
                  Container(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFeatureChip(Icons.king_bed_rounded, '$bedrooms ch.'),
                        SizedBox(width: 8),
                        _buildFeatureChip(Icons.bathtub_rounded, '$bathrooms sdb'),
                        SizedBox(width: 8),
                        _buildFeatureChip(Icons.square_foot_rounded, '${surface}m²'),
                      ],
                    ),
                  ),

                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '$price\$/mois',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _lightColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _greyColor),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: _greyColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 44,
      margin: EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: _lightColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Rechercher une ville, un quartier...',
          prefixIcon: Icon(Icons.search_rounded, color: _greyColor),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        style: TextStyle(fontSize: 15),
      ),
    );
  }

  Widget _buildApplyFiltersButton() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          // Fermer le clavier avant de changer de page
          FocusScope.of(context).unfocus();
          setState(() {
            _showFilters = false;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Afficher les résultats',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _priceRange = RangeValues(500, 2500);
      _selectedPropertyType = 'Tous';
      _selectedBedrooms = null;
      _selectedCity = null;
      _selectedCommune = null;
      _minPriceController.text = '500';
      _maxPriceController.text = '2500';
      _bedroomsController.clear();
    });
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _bedroomsController.dispose();
    _minPriceFocus.dispose();
    _maxPriceFocus.dispose();
    _bedroomsFocus.dispose();
    super.dispose();
  }
}