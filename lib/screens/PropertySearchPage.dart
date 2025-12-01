import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../controllers/PropertyCtrl.dart';
import '../controllers/LocationController.dart';
import '../models/CityModel.dart';
import '../models/CommuneModel.dart';
import '../models/PropertyModel.dart';
import '../utils/FavoriteEartIcon.dart';
import '../utils/Routes.dart';

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
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showSearchLoader = false;

  // Contrôles de localisation
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
  final List<String> _propertyTypes = ['Tous', 'Studio', 'Apparts', 'Maisons', 'Bureau', 'Hotels', 'Vacances'];

  // Remplacement des listes statiques par des données dynamiques
  List<String> _cities = [];
  List<String> _communes = [];

  // Mappings des types de propriétés
  final Map<String, int> _propertyTypeMapping = {
    'Tous': 0,
    'Studio': 1,
    'Apparts': 2,
    'Maisons': 3,
    'Bureau': 4,
    'Hotels': 5,
    'Vacances': 6,
  };

  // Timer pour le debounce de recherche
  Timer? _searchDebounce;

  // Refresh controller pour pull-to-refresh
  final RefreshController _refreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    _minPriceController.text = _priceRange.start.toInt().toString();
    _maxPriceController.text = _priceRange.end.toInt().toString();

    _minPriceController.addListener(_updatePriceRange);
    _maxPriceController.addListener(_updatePriceRange);

    // Charger les propriétés et les données de localisation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() async {
    final propertyController = Provider.of<PropertyController>(context, listen: false);
    final locationController = Provider.of<LocationController>(context, listen: false);

    // Charger les propriétés
    propertyController.getAllProperty();

    // Charger les données de localisation
    await locationController.loadAllData();

    // Vérifier les relations entre villes, districts et communes
    print("=== VERIFICATION DES RELATIONS ===");
    print("🏙️ Villes chargées: ${locationController.cities.length}");
    print("📊 Districts chargés: ${locationController.districts.length}");
    print("🏘️ Communes chargées: ${locationController.communes.length}");

    // Vérifier quelques exemples de relations
    if (locationController.cities.isNotEmpty && locationController.communes.isNotEmpty) {
      final testCity = locationController.cities.first;
      print("🔍 Test pour la ville: ${testCity.name} (ID: ${testCity.cityId})");

      final communesForTestCity = locationController.communes.where((commune) {
        return commune.district?.city?.cityId == testCity.cityId;
      }).toList();

      print("🏘️ Communes liées à ${testCity.name}: ${communesForTestCity.length}");
      for (var commune in communesForTestCity.take(3)) {
        print("   - ${commune.name} (District: ${commune.district?.name})");
      }
    }

    // Mettre à jour les listes de villes et communes
    if (mounted) {
      setState(() {
        _cities = locationController.cities
            .where((city) => city.name != null && city.name!.isNotEmpty)
            .map((city) => city.name!)
            .toList();

        _communes = locationController.communes
            .where((commune) => commune.name != null && commune.name!.isNotEmpty)
            .map((commune) => commune.name!)
            .toList();
      });

      print("✅ Interface initialisée: ${_cities.length} villes, ${_communes.length} communes");
    }
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

  void _onCityChanged(String? selectedCity) {
    final locationController = Provider.of<LocationController>(context, listen: false);

    setState(() {
      _selectedCity = selectedCity;
      _selectedCommune = null;
    });

    if (selectedCity != null) {
      print("🏙️ Ville sélectionnée: $selectedCity");

      try {
        // Trouver la ville sélectionnée
        final city = locationController.cities.firstWhere(
              (city) => city.name == selectedCity,
          orElse: () => CityModel(),
        );

        if (city.cityId != null) {
          print("🔍 Recherche des communes pour: ${city.name} (ID: ${city.cityId})");

          // Utiliser la méthode directe
          final communesForCity = locationController.getCommunesForCity(city.cityId!);

          if (communesForCity.isNotEmpty) {
            setState(() {
              _communes = communesForCity
                  .where((commune) => commune.name != null && commune.name!.isNotEmpty)
                  .map((commune) => commune.name!)
                  .toList();
            });
            print("✅ ${_communes.length} communes chargées pour ${city.name}");
          } else {
            print("⚠️ Aucune commune trouvée pour ${city.name}");
            _showAllCommunes(locationController);
          }
        } else {
          print("❌ Aucun ID trouvé pour la ville: $selectedCity");
          _showAllCommunes(locationController);
        }
      } catch (e) {
        print("❌ Erreur lors du filtrage des communes: $e");
        _showAllCommunes(locationController);
      }
    } else {
      _showAllCommunes(locationController);
    }
  }

  void _showAllCommunes(LocationController locationController) {
    setState(() {
      _communes = locationController.communes
          .where((commune) => commune.name != null && commune.name!.isNotEmpty)
          .map((commune) => commune.name!)
          .toList();
    });
    print("🌍 Affichage de toutes les communes: ${_communes.length}");
  }

  void _applyFilters() {
    final propertyController = Provider.of<PropertyController>(context, listen: false);
    final locationController = Provider.of<LocationController>(context, listen: false);

    // Convertir les filtres UI en paramètres API
    int? propertyTypeId = _propertyTypeMapping[_selectedPropertyType];
    if (propertyTypeId == 0) propertyTypeId = null; // "Tous" = pas de filtre

    // Gérer le type de transaction (sold parameter)
    bool? sold;
    if (_selectedTransaction == 'Location') {
      sold = false; // Properties disponibles pour location
    } else if (_selectedTransaction == 'Achat') {
      sold = true; // Properties vendues (ou à vendre)
    }

    // Récupérer les IDs des villes et communes sélectionnées
    int? cityId;
    int? communeId;

    if (_selectedCity != null) {
      final city = locationController.cities.firstWhere(
            (c) => c.name == _selectedCity,
        orElse: () => CityModel(),
      );
      cityId = city.cityId;
    }

    if (_selectedCommune != null) {
      final commune = locationController.communes.firstWhere(
            (c) => c.name == _selectedCommune,
        orElse: () => CommuneModel(),
      );
      communeId = commune.communeId;
    }

    int? bedrooms = _selectedBedrooms != null ? int.tryParse(_selectedBedrooms!) : null;

    // Appliquer les filtres selon l'API
    propertyController.filterProperties(
      sold: sold,
      minPrice: _priceRange.start,
      maxPrice: _priceRange.end,
      typeMaison: propertyTypeId,
      city: cityId,
      commune: communeId,
      room: bedrooms,
      sortBy: 'price',
      sortOrder: 'asc',
    );

    setState(() {
      _showFilters = false;
    });
  }

  void _performSearch() {
    final controller = Provider.of<PropertyController>(context, listen: false);
    final searchTerm = _searchController.text.trim();

    if (searchTerm.isNotEmpty) {
      setState(() {
        _showSearchLoader = true;
      });

      controller.searchProperties(searchTerm).then((_) {
        if (mounted) {
          setState(() {
            _showSearchLoader = false;
          });
        }
      });
    } else {
      controller.resetFilters();
      setState(() {
        _showSearchLoader = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        _showSearchLoader = false;
        _isSearching = false;
      });
      final controller = Provider.of<PropertyController>(context, listen: false);
      controller.resetFilters();
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchLoader = true;
    });

    _searchDebounce = Timer(Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  void _resetFilters() {
    final locationController = Provider.of<LocationController>(context, listen: false);

    setState(() {
      _priceRange = RangeValues(500, 2500);
      _selectedPropertyType = 'Tous';
      _selectedBedrooms = null;
      _selectedCity = null;
      _selectedCommune = null;
      _selectedTransaction = 'Location';
      _minPriceController.text = '500';
      _maxPriceController.text = '2500';
      _bedroomsController.clear();
      _searchController.clear();
      _isSearching = false;
      _showSearchLoader = false;

      // Réinitialiser les communes pour montrer toutes
      _communes = locationController.communes
          .where((commune) => commune.name != null)
          .map((commune) => commune.name!)
          .toList();
    });

    final controller = Provider.of<PropertyController>(context, listen: false);
    controller.resetFilters();
  }

  // Méthode pour gérer le pull-to-refresh
  Future<void> _handlePullToRefresh(PropertyController propertyCtrl) async {
    try {
      await propertyCtrl.refreshProperties();
      _refreshController.refreshCompleted();
      _showRefreshSuccess();
    } catch (e) {
      print("❌ Erreur refresh: $e");
      _refreshController.refreshFailed();
      _showRefreshError();
    }
  }

  void _showRefreshSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Données à jour', style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showRefreshError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Erreur de rafraîchissement', style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 3),
      ),
    );
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
      toolbarHeight: 80,
      actions: [
        _buildFilterBadge(),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFilterBadge() {
    final filterCount = _getActiveFilterCount();

    return Container(
      margin: EdgeInsets.only(top: 8, bottom: 8),
      child: Stack(
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
      ),
    );
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedPropertyType != 'Tous') count++;
    if (_selectedBedrooms != null && _selectedBedrooms!.isNotEmpty) count++;
    if (_priceRange.start > 500 || _priceRange.end < 2500) count++;
    if (_selectedCity != null) count++;
    if (_selectedCommune != null) count++;
    if (_selectedTransaction != 'Location') count++;
    return count;
  }

  Widget _buildSimplifiedFilterPanel() {
    return GestureDetector(
      onTap: () {
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
    return Consumer<LocationController>(
      builder: (context, locationController, child) {
        // Afficher un loader si les données ne sont pas encore chargées
        if (locationController.loading && _cities.isEmpty) {
          return _buildLocationLoader();
        }

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
              _onCityChanged,
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
      },
    );
  }

  Widget _buildLocationLoader() {
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
        _buildShimmerLoader(height: 56),
        SizedBox(height: 16),
        _buildShimmerLoader(height: 56),
      ],
    );
  }

  Widget _buildShimmerLoader({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _primaryColor,
          ),
        ),
      ),
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
      case 'Studio':
        return Icons.weekend;
      case 'Apparts':
        return Icons.apartment;
      case 'Maisons':
        return Icons.house;
      case 'Bureau':
        return Icons.business_center;
      case 'Hotels':
        return Icons.hotel;
      case 'Vacances':
        return Icons.beach_access;
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
    return Consumer<PropertyController>(
      builder: (context, controller, child) {
        // Afficher le loader de recherche
        if (_showSearchLoader) {
          return _buildSearchLoader();
        }

        if (controller.loading && controller.properties.isEmpty) {
          return Center(
            child: _buildMainLoader(),
          );
        }

        if (controller.properties.isEmpty) {
          return _buildEmptyState(controller);
        }

        return SmartRefresher(
          controller: _refreshController,
          enablePullDown: true,
          enablePullUp: false,
          header: CustomHeader(
            builder: (context, mode) {
              return _buildRefreshHeader(mode!, controller);
            },
          ),
          onRefresh: () async {
            await _handlePullToRefresh(controller);
          },
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: controller.properties.length,
            itemBuilder: (context, index) => _buildPropertyListItem(controller.properties[index]),
          ),
        );
      },
    );
  }

  Widget _buildRefreshHeader(RefreshStatus mode, PropertyController propertyCtrl) {
    Widget content;

    switch (mode) {
      case RefreshStatus.idle:
        content = _buildHeaderItem(
          icon: Icons.arrow_downward,
          text: "Tirer pour rafraîchir",
          color: Colors.grey,
        );
        break;
      case RefreshStatus.canRefresh:
        content = _buildHeaderItem(
          icon: Icons.arrow_upward,
          text: "Relâcher pour rafraîchir",
          color: _primaryColor,
        );
        break;
      case RefreshStatus.refreshing:
        content = _buildRefreshInProgress();
        break;
      case RefreshStatus.completed:
        content = _buildHeaderItem(
          icon: Icons.check_circle,
          text: "Rafraîchissement terminé",
          color: Colors.green,
        );
        break;
      case RefreshStatus.failed:
        content = _buildHeaderItem(
          icon: Icons.error_outline,
          text: "Échec du rafraîchissement",
          color: Colors.red,
        );
        break;
      default:
        content = Container();
    }

    return Container(
      height: 80,
      child: Center(child: content),
    );
  }

  Widget _buildHeaderItem({required IconData icon, required String text, required Color color}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildRefreshInProgress() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Mise à jour...",
          style: TextStyle(color: _primaryColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSearchLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animation de recherche
          AnimatedContainer(
            duration: Duration(milliseconds: 1000),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _lightColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Icône de recherche avec rotation
                AnimatedRotation(
                  duration: Duration(milliseconds: 2000),
                  turns: 1,
                  child: Icon(
                    Icons.search_rounded,
                    size: 50,
                    color: _primaryColor.withOpacity(0.7),
                  ),
                ),

                // Points tournants autour de l'icône
                ...List.generate(3, (index) => Positioned(
                  right: 15 + index * 10,
                  top: 30 + index * 15,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 1500 + index * 300),
                    curve: Curves.easeInOut,
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                )),
              ],
            ),
          ),

          SizedBox(height: 40),

          // Texte de recherche
          Text(
            'Recherche en cours...',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _darkColor,
            ),
          ),

          SizedBox(height: 12),

          Text(
            'Nous cherchons les propriétés correspondant\nà votre recherche',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _greyColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 20),

          // Loader personnalisé
          Container(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _primaryColor,
              backgroundColor: _primaryColor.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainLoader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            color: _primaryColor,
            backgroundColor: _primaryColor.withOpacity(0.1),
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Chargement des propriétés...',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: _greyColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(PropertyController controller) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration animée
            AnimatedContainer(
              duration: Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: _lightColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Icône principale avec effet de pulsation
                  AnimatedScale(
                    duration: Duration(milliseconds: 2000),
                    scale: 1.0,
                    curve: Curves.elasticOut,
                    child: Icon(
                      Icons.search_off_rounded,
                      size: 80,
                      color: _primaryColor.withOpacity(0.7),
                    ),
                  ),

                  // Effet de particules autour de l'icône
                  ...List.generate(3, (index) => Positioned(
                    right: 20 + index * 15,
                    top: 40 + index * 20,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 1500 + index * 300),
                      curve: Curves.easeInOut,
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  )),
                ],
              ),
            ),

            SizedBox(height: 40),

            // Titre avec animation de fade
            AnimatedOpacity(
              duration: Duration(milliseconds: 600),
              opacity: 1.0,
              child: Text(
                _isSearching ? 'Aucun résultat trouvé' : 'Aucune propriété disponible',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _darkColor,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: 12),

            // Description avec animation décalée
            AnimatedOpacity(
              duration: Duration(milliseconds: 800),
              opacity: 1.0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  controller.loading
                      ? 'Recherche en cours...'
                      : _isSearching
                      ? 'Aucune propriété ne correspond à votre recherche. '
                      'Essayez de modifier vos termes de recherche ou élargissez vos critères.'
                      : 'Aucune propriété ne correspond à vos critères de recherche. '
                      'Essayez de modifier vos filtres ou élargissez votre recherche.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _greyColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyListItem(PropertyModel property) {
    // Utilisation des vraies images du modèle PropertyModel
    final firstImage = property.propertyImage?.isNotEmpty ?? false
        ? property.propertyImage!.first
        : null;
    final imageUrl = firstImage != null
        ? "${firstImage.path ?? firstImage.path}"
        : null;

    final priceText = _selectedTransaction == 'Location'
        ? '${property.price?.toStringAsFixed(0) ?? '0'}\$/mois'
        : '${property.price?.toStringAsFixed(0) ?? '0'}\$';

    return InkWell(
      onTap: () {_navigateToDetail(property);},
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
            // Image avec le même style que votre composant horizontal
            Container(
              width: 120,
              height: 175,
              margin: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl != null
                    ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildImagePlaceholder(),
                  errorWidget: (context, url, error) => _buildImagePlaceholder(),
                )
                    : _buildImagePlaceholder(),
              ),
            ),

            // Détails
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 12, right: 12, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête avec type et favoris
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getPropertyTypeLabel(property.propertyType?.propertyTypeId ?? 0),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                        Spacer(),

                        if (property.propertyId != null)
                          FavoriteHeartIcon(
                            propertyId: property.propertyId.toString(),
                            size: 24,
                            splashRadius: 20,
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    // Titre
                    Text(
                      property.title ?? 'Sans titre',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: _darkColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 4),

                    // Adresse
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: _greyColor),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.address ?? 'Adresse non disponible',
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

                    // Caractéristiques
                    Container(
                      height: 30,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          if (property.bedrooms != null)
                            _buildFeatureChip(Icons.king_bed_rounded, '${property.bedrooms} ch.'),
                          SizedBox(width: 8),
                          if (property.bathroom != null)
                            _buildFeatureChip(Icons.bathtub_rounded, '${property.bathroom} sdb'),
                          SizedBox(width: 8),
                          if (property.surface != null)
                            _buildFeatureChip(Icons.square_foot_rounded, '${property.surface}m²'),
                          if (property.rooms != null)
                            _buildFeatureChip(FontAwesomeIcons.doorClosed, '${property.rooms} pièces'),
                        ].where((element) => element != null).cast<Widget>().toList(),
                      ),
                    ),

                    SizedBox(height: 8),

                    // Prix et statut
                    Row(
                      children: [
                        Text(
                          priceText,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        Spacer(),
                        if (property.sold == true)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Vendu',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
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
      ),
    );
  }

  void _navigateToDetail(PropertyModel property) {
    Navigator.pushNamed(
      context,
      Routes.detailPageRoute,
      arguments: property,
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        switch (text) {
          case 'Élargir la zone de recherche':
            setState(() {
              _selectedCity = null;
              _selectedCommune = null;
            });
            break;
          case 'Augmenter le budget':
            setState(() {
              _priceRange = RangeValues(0, 10000);
              _minPriceController.text = '0';
              _maxPriceController.text = '10000';
            });
            break;
          case 'Tous types de biens':
            setState(() {
              _selectedPropertyType = 'Tous';
            });
            break;
        }
        _applyFilters();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: _primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.photo_outlined,
          size: 32,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  String _getPropertyTypeLabel(int type) {
    switch (type) {
      case 1: return 'Studio';
      case 2: return 'Apparts';
      case 3: return 'Maisons';
      case 4: return 'Bureau';
      case 5: return 'Hotels';
      case 6: return 'Vacances';
      default: return 'Autre';
    }
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
      margin: EdgeInsets.only(top: 8, bottom: 8, right: 8),
      decoration: BoxDecoration(
        color: _lightColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une ville, un quartier, une adresse...',
                prefixIcon: Icon(Icons.search_rounded, color: _greyColor),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: _greyColor, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _isSearching = false;
                      _showSearchLoader = false;
                    });
                    _performSearch();
                  },
                )
                    : null,
              ),
              style: TextStyle(fontSize: 15),
              onSubmitted: (value) => _performSearch(),
              onChanged: _onSearchChanged,
            ),
          ),

          if (_showSearchLoader)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApplyFiltersButton() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: 56,
      child: ElevatedButton(
        onPressed: _applyFilters,
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _bedroomsController.dispose();
    _searchController.dispose();
    _minPriceFocus.dispose();
    _maxPriceFocus.dispose();
    _bedroomsFocus.dispose();
    _refreshController.dispose();
    super.dispose();
  }
}