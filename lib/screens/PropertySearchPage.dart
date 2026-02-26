import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../controllers/PropertyCtrl.dart';
import '../controllers/ServiceController.dart';
import '../models/ServiceModel.dart';
import '../controllers/LocationController.dart';
import '../models/CityModel.dart';
import '../models/CommuneModel.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/PrestationModel.dart'; // Added
import '../utils/city_suggestions.dart';
import '../widgets/LocationAutocompleteWidget.dart';
import '../utils/FavoriteEartIcon.dart';
import '../utils/Routes.dart';
import '../controllers/AuthentificationCtrl.dart';
import '../controllers/provider/FavoriteProvider.dart';
import 'package:shimmer/shimmer.dart';

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
  RangeValues _priceRange = RangeValues(10, 400);
  String _selectedPropertyType = 'Tous';
  String? _selectedBedrooms;
  bool _showFilters = false;
  bool _isLoadingProperties = true;
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showSearchLoader = false;

  // Mode de recherche
  String _searchType = 'Propriétés'; // 'Propriétés' ou 'Services'

  // ─── Infinity Scroll ────────────────────────────────────────────────────────
  static const int _pageSize = 15;

  // Propriétés
  int _visiblePropertyCount = _pageSize;  // Combien on affiche actuellement
  bool _isLoadingMoreProperties = false;  // Loader du bas pour propriétés
  final ScrollController _propertyScrollController = ScrollController();

  // Services
  int _visibleServiceCount = _pageSize;   // Combien on affiche actuellement
  bool _isLoadingMoreServices = false;    // Loader du bas pour services
  final ScrollController _serviceScrollController = ScrollController();
  // ────────────────────────────────────────────────────────────────────────────

  // Filtres Services
  String? _selectedServiceCategory;
  List<String> _serviceCategories = [];
  List<PrestationModel> _allPrestations = [];
  List<PrestationModel> _filteredPrestations = [];
  bool _isLoadingServices = false;

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
  final List<String> _propertyTypes = [
    'Tous', 
    'Studio', 
    'Apparts', 
    'Maisons', 
    'Bureau', 
    'Hotels', 
    'Vacances',
    'Salle de fête',
    'Salle funéraires',
    'Terrain',
    'Entrepôt'
  ];

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
    'Salle funéraires': 7,
    'Salle de fête': 8,
    'Terrain': 9,
    'Entrepôt': 10,
  };

  // Timer pour le debounce de recherche
  Timer? _searchDebounce;

  // Refresh controllers pour pull-to-refresh
  final RefreshController _propertyRefreshController = RefreshController();
  final RefreshController _serviceRefreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    _minPriceController.text = _priceRange.start.toInt().toString();
    _maxPriceController.text = _priceRange.end.toInt().toString();

    _minPriceController.addListener(_updatePriceRange);
    _maxPriceController.addListener(_updatePriceRange);

    // Listeners pour le scroll infini
    _propertyScrollController.addListener(() {
      if (_propertyScrollController.position.pixels >=
          _propertyScrollController.position.maxScrollExtent - 200) {
        _loadMoreProperties();
      }
    });
    _serviceScrollController.addListener(() {
      if (_serviceScrollController.position.pixels >=
          _serviceScrollController.position.maxScrollExtent - 200) {
        _loadMoreServices();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  /// Révèle plus de propriétés et charge la page suivante de l'API si nécessaire
  void _loadMoreProperties() async {
    final ctrl = Provider.of<PropertyController>(context, listen: false);
    final allProps = ctrl.allProperties;
    final totalLoaded = allProps.length;

    if (_isLoadingMoreProperties) return;

    // 1. D'abord, révéler le buffer local par lots de 15
    if (_visiblePropertyCount < totalLoaded) {
      setState(() => _isLoadingMoreProperties = true);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _visiblePropertyCount = (_visiblePropertyCount + _pageSize).clamp(0, totalLoaded);
        _isLoadingMoreProperties = false;
      });
      return;
    }

    // 2. Si on a tout révélé mais que l'API a encore des données (Infinity Scroll réel)
    if (ctrl.hasMoreData) {
      setState(() => _isLoadingMoreProperties = true);
      
      final searchTerm = _searchController.text.trim();
      if (_isSearching && searchTerm.isNotEmpty) {
        await ctrl.searchProperties(searchTerm, isLoadMore: true);
      } else {
        await _applyFiltersAsync(ctrl, isLoadMore: true);
      }

      if (!mounted) return;
      setState(() {
        // Mettre à jour visibleCount pour inclure les nouveaux arrivants
        _visiblePropertyCount = ctrl.allProperties.length;
        _isLoadingMoreProperties = false;
      });
    }
  }

  /// Révèle plus de services et charge la page suivante de l'API si nécessaire
  void _loadMoreServices() async {
    final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
    final totalInList = _filteredPrestations.length;

    if (_isLoadingMoreServices) return;

    // 1. Révéler le buffer local
    if (_visibleServiceCount < totalInList) {
      setState(() => _isLoadingMoreServices = true);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _visibleServiceCount = (_visibleServiceCount + _pageSize).clamp(0, totalInList);
        _isLoadingMoreServices = false;
      });
      return;
    }

    // 2. Real API fetch for next page if no local search active
    bool isSearchingLocally = _searchController.text.isNotEmpty;
    if (!isSearchingLocally && serviceCtrl.hasMoreData) {
      setState(() => _isLoadingMoreServices = true);
      
      await serviceCtrl.fetchAllPrestations(isLoadMore: true);
      
      if (!mounted) return;
      setState(() {
        _allPrestations = List.from(serviceCtrl.prestations);
        _filteredPrestations = List.from(serviceCtrl.prestations);
        _visibleServiceCount = _filteredPrestations.length;
        _isLoadingMoreServices = false;
      });
    }
  }

  void _initializeData() async {
    final propertyController = Provider.of<PropertyController>(context, listen: false);
    final locationController = Provider.of<LocationController>(context, listen: false);
    final serviceController = Provider.of<ServiceController>(context, listen: false);

    // Charger les services (Prestations)
    setState(() {
      _isLoadingServices = true;
    });
    
    if (serviceController.serviceIdToNameMap.isEmpty) {
      serviceController.fetchServiceAccounts();
    }

    // Utiliser fetchAllPrestations au lieu de fetchServices
    await serviceController.fetchAllPrestations();
    
    if (mounted) {
      setState(() {
        // Extraire les catégories uniques des prestations
        _allPrestations = List.from(serviceController.prestations);
        _filteredPrestations = List.from(serviceController.prestations);
        
        // Extraire les catégories dynamiquement depuis le mapping si disponible
        if (serviceController.serviceIdToNameMap.isNotEmpty) {
          _serviceCategories = serviceController.serviceIdToNameMap.values
              .map((name) => name[0].toUpperCase() + name.substring(1).toLowerCase())
              .toSet() // Éliminer doublons
              .toList();
          _serviceCategories.sort();
        } else {
          _serviceCategories = [
            'Plombier', 'Electricien', 'Menuisier', 'Peintre', 'Maçon', 
            'Jardinier', 'Nettoyage', 'Déménagement', 'Traiteur', 'Photographe'
          ];
        }
        
        _isLoadingServices = false;
      });
    }

    // getAllProperty() gère déjà :
    // 1. Chargement cache SQL instantané (standard + spéciales locales)
    // 2. Sync online en arrière-plan avec re-fusion automatique des spéciales
    try {
      if (mounted) setState(() => _isLoadingProperties = true);

      await propertyController.getAllProperty();

      if (mounted) {
        setState(() {
          _visiblePropertyCount = _pageSize; // Démarrer avec 15 items visibles
          _isLoadingProperties = false;
        });
      }
    } catch (e) {
      print("Erreur chargement propriétés: $e");
      if (mounted) setState(() => _isLoadingProperties = false);
    }

    // Charger les données de localisation
    await locationController.loadAllData();

    // Mettre à jour les listes de villes et communes
    if (mounted) {
      setState(() {
        _cities = CitySuggestions.cities;

        _communes = locationController.communes
            .where((commune) => commune.name != null && commune.name!.isNotEmpty)
            .map((commune) => commune.name!)
            .toList();
      });
    }
  }


  void _updatePriceRange({StateSetter? setModalState}) {
    final min = int.tryParse(_minPriceController.text) ?? 10;
    final max = int.tryParse(_maxPriceController.text) ?? 400;
    
    final fn = () {
      if (min <= max) {
        _priceRange = RangeValues(min.toDouble(), max.toDouble());
      }
    };

    setState(fn);
    if (setModalState != null) setModalState(fn);
  }

  void _onCityChanged(String? selectedCity, {StateSetter? setModalState}) {
    final locationController = Provider.of<LocationController>(context, listen: false);
    
    // Preparer la nouvelle liste de communes avant de mettre à jour l'état
    List<String> newCommunes = [];
    String? normalizedCity = selectedCity?.trim().toLowerCase();

    if (normalizedCity != null && normalizedCity.isNotEmpty) {
      if (normalizedCity == 'matadi') {
        newCommunes = ['Matadi', 'Nzanza', 'Mvuzi'];
      } else {
        try {
          final city = locationController.cities.firstWhere(
            (city) => (city.name ?? '').trim().toLowerCase() == normalizedCity,
            orElse: () => CityModel(cityId: null),
          );

          if (city.cityId != null) {
            final communesForCity = locationController.getCommunesForCity(city.cityId!);
            if (communesForCity.isNotEmpty) {
              newCommunes = communesForCity
                  .where((commune) => commune.name != null && commune.name!.isNotEmpty)
                  .map((commune) => commune.name!.trim())
                  .toList();
            } else if (normalizedCity == 'kinshasa') {
              newCommunes = locationController.communes
                  .where((commune) => commune.name != null && commune.name!.isNotEmpty)
                  .map((commune) => commune.name!.trim())
                  .toList();
            }
          } else if (normalizedCity == 'kinshasa') {
            newCommunes = locationController.communes
                .where((commune) => commune.name != null && commune.name!.isNotEmpty)
                .map((commune) => commune.name!.trim())
                .toList();
          }
        } catch (_) {
          newCommunes = [];
        }
      }
    } else {
      // Pour les autres villes, pas de suggestions de communes
      newCommunes = [];
    }

    final fn = () {
      _selectedCity = selectedCity;
      _selectedCommune = null; 
      _communes = newCommunes;
    };

    if (mounted) setState(fn);
    if (setModalState != null) setModalState(fn);
  }

  void _showAllCommunes(LocationController locationController, {StateSetter? setModalState}) {
    final fn = () {
      _communes = locationController.communes
          .where((commune) => commune.name != null && commune.name!.isNotEmpty)
          .map((commune) => commune.name!.trim())
          .toList();
    };
    if (mounted) setState(fn);
    if (setModalState != null) setModalState(fn);
  }



  void _performSearch() {
    final searchTerm = _searchController.text.trim();

    if (_searchType == 'Propriétés') {
       final controller = Provider.of<PropertyController>(context, listen: false);
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
    } else {
       // Search for Services (Local filtering)
       setState(() {
         _showSearchLoader = true;
       });
       
       // Simulate network delay for better UX
       Future.delayed(Duration(milliseconds: 500), () {
         if (mounted) {
           setState(() {
             if (searchTerm.isEmpty) {
               _filteredPrestations = List.from(_allPrestations);
             } else {
               _filteredPrestations = _allPrestations.where((s) {
                 final title = s.title?.toLowerCase() ?? '';
                 final desc = s.description?.toLowerCase() ?? '';
                 final query = searchTerm.toLowerCase();
                 return title.contains(query) || desc.contains(query);
               }).toList();
             }
             _showSearchLoader = false;
           });
         }
       });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    if (value.trim().isEmpty) {
      if (_searchType == 'Propriétés') {
         final controller = Provider.of<PropertyController>(context, listen: false);
         controller.resetFilters();
      } else {
        setState(() {
          _filteredPrestations = List.from(_allPrestations);
        });
      }
      setState(() {
        _showSearchLoader = false;
        _isSearching = false;
      });
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
      _priceRange = RangeValues(10, 400);
      _selectedPropertyType = 'Tous';
      _selectedBedrooms = null;
      _selectedCity = null;
      _selectedCommune = null;
      _selectedTransaction = 'Location';
      _selectedServiceCategory = null; 
      _minPriceController.text = '10';
      _maxPriceController.text = '400';
      _bedroomsController.clear();
      _searchController.clear();
      _isSearching = false;
      _showSearchLoader = false;
      
      // Reset visibility counts to show first page
      _visiblePropertyCount = _pageSize;
      _visibleServiceCount = _pageSize;

      // Réinitialiser les communes pour montrer toutes
      _communes = locationController.communes
          .where((commune) => commune.name != null)
          .map((commune) => commune.name!.trim())
          .toList();
      
      // Reset prestations list
      _filteredPrestations = List.from(_allPrestations);
    });

    final controller = Provider.of<PropertyController>(context, listen: false);
    controller.resetFilters();
  }

  // Méthode pour gérer le pull-to-refresh
  Future<void> _handlePullToRefresh(PropertyController propertyCtrl, {RefreshController? controller}) async {
    final activeController = controller ?? (_searchType == 'Propriétés' ? _propertyRefreshController : _serviceRefreshController);
    
    try {
      // 0. Sync Favorites (Fix for red hearts issue)
      if (mounted) {
        final authCtrl = Provider.of<AuthentificationCtrl>(context, listen: false);
        final favProvider = Provider.of<FavoriteProvider>(context, listen: false);
        if (authCtrl.token.isNotEmpty && authCtrl.user.userId != null) {
          // Don't await strictly to avoid blocking UI, but it runs in parallel
          favProvider.syncFavorites(authCtrl.user.userId.toString()); 
        }
      }

      // 1. Refresh Logic respecting partial state
      if (_searchType == 'Propriétés') {
         // Check if filters are active or search is active
         bool hasFilters = _getActiveFilterCount() > 0;
         bool hasSearch = _isSearching && _searchController.text.isNotEmpty;

         if (hasSearch) {
           // If searching, just re-run search
           await propertyCtrl.searchProperties(_searchController.text.trim());
         } else if (hasFilters) {
           // If filtered, re-apply filters (calls API with filters)
           // Extract logic from _applyFilters to be awaitable here
           await _applyFiltersAsync(propertyCtrl); 
         } else {
           // Default: Refresh All
           await propertyCtrl.refreshProperties(forceSync: true);
         }
         
         // Always sync special categories
         await propertyCtrl.syncAllSpecialCategories();

      } else {
        // Services Refresh
        if (mounted) {
          final serviceCtrl = Provider.of<ServiceController>(context, listen: false);
          await serviceCtrl.fetchAllPrestations();
          setState(() {
             _allPrestations = List.from(serviceCtrl.prestations);
             // Re-apply local service search if needed
              if (_searchController.text.isNotEmpty) {
                 final query = _searchController.text.toLowerCase();
                 _filteredPrestations = _allPrestations.where((s) {
                   final title = s.title?.toLowerCase() ?? '';
                   final desc = s.description?.toLowerCase() ?? '';
                   return title.contains(query) || desc.contains(query);
                 }).toList();
              } else {
                _filteredPrestations = List.from(serviceCtrl.prestations);
                // TODO: Re-apply local category filters if any
                if (_selectedServiceCategory != null) {
                   _onServiceCategoryRefilter(); 
                }
              }
          });
        }
      }
      
      activeController.refreshCompleted();
    } catch (e) {
      print("❌ Erreur refresh: $e");
      activeController.refreshFailed();
    }
  }

  // Helper to re-apply service filters locally after refresh
  void _onServiceCategoryRefilter() {
      if (_selectedServiceCategory == null) return;
      
      _filteredPrestations = _filteredPrestations.where((prestation) {
         final serviceName = _getServiceName(prestation.serviceId);
         if (serviceName == null) return false;
         if (!serviceName.toLowerCase().contains(_selectedServiceCategory!.toLowerCase()) && 
             !_selectedServiceCategory!.toLowerCase().contains(serviceName.toLowerCase())) {
           return false;
         }
         return true;
      }).toList();
  }

  // Async version of applyFilters for refresh and load more
  Future<void> _applyFiltersAsync(PropertyController propertyController, {bool isLoadMore = false}) async {
      final locationController = Provider.of<LocationController>(context, listen: false);

      int? propertyTypeId = _propertyTypeMapping[_selectedPropertyType];
      if (propertyTypeId == 0) propertyTypeId = null;

      bool? sold;
      if (_selectedTransaction == 'Location') sold = false;
      else if (_selectedTransaction == 'Achat') sold = true;

      int? cityId;
      int? communeId;

      if (_selectedCity != null) {
        final city = locationController.cities.firstWhere(
          (c) => c.name == _selectedCity,
          orElse: () => CityModel(cityId: null),
        );
        cityId = city.cityId;
      }

      if (_selectedCommune != null) {
         final commune = locationController.communes.firstWhere(
          (c) => c.name == _selectedCommune,
          orElse: () => CommuneModel(communeId: null),
        );
        communeId = commune.communeId;
      }

      int? bedrooms = _selectedBedrooms != null ? int.tryParse(_selectedBedrooms!) : null;

      await propertyController.filterProperties(
        sold: sold,
        minPrice: _priceRange.start,
        maxPrice: _priceRange.end,
        typeMaison: propertyTypeId,
        city: cityId,
        commune: communeId,
        room: bedrooms,
        sortBy: 'id',
        sortOrder: 'desc',
        isLoadMore: isLoadMore,
      );
  }

  // Removed _showRefreshSuccess and _showRefreshError per user request

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      appBar: _buildAppBar(),
      body: _searchType == 'Propriétés' ? _buildPropertyList() : _buildServiceList(),
     
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle and Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filtres',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1D26),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  _resetFilters();
                                });
                                Navigator.pop(context);
                                _showFilterModal();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: _primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                backgroundColor: _primaryColor.withOpacity(0.08),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Réinitialiser', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchType == 'Propriétés') ...[
                            // Transaction Zone
                            _buildSectionHeader(Icons.swap_horiz_rounded, 'Transaction'),
                            const SizedBox(height: 12),
                            _buildDropdownField(
                              'Je cherche à',
                              _selectedTransaction,
                              ['Location', 'Achat'],
                              Icons.swap_horiz_rounded,
                              (value) {
                                setModalState(() {
                                  _selectedTransaction = value ?? 'Location';
                                });
                              },
                            ),
                            const SizedBox(height: 24),

                            // Localisation Zone
                            _buildSectionHeader(Icons.location_on_rounded, 'Localisation'),
                            const SizedBox(height: 12),
                            _buildLocationSection(setModalState: setModalState),
                            const SizedBox(height: 24),

                            // Budget Zone
                            _buildSectionHeader(Icons.payments_rounded, 'Budget'),
                            const SizedBox(height: 12),
                            _buildModernPriceRange(setModalState: setModalState),
                            const SizedBox(height: 24),

                            // Type de bien Zone
                            _buildSectionHeader(Icons.home_work_rounded, 'Type de bien'),
                            const SizedBox(height: 12),
                            _buildDropdownField(
                              'Type de bien',
                              _selectedPropertyType,
                              _propertyTypes,
                              Icons.home_work_rounded,
                              (value) {
                                setModalState(() {
                                  _selectedPropertyType = value ?? 'Tous';
                                });
                              },
                            ),
                          ] else ...[
                            // Localisation Zone (Service)
                            _buildSectionHeader(Icons.location_on_rounded, 'Localisation'),
                            const SizedBox(height: 12),
                            _buildLocationSection(setModalState: setModalState),
                            const SizedBox(height: 24),

                            // Service Category Zone
                            _buildSectionHeader(Icons.work_rounded, 'Profession & Service'),
                            const SizedBox(height: 12),
                            _buildDropdownField(
                              'un service ',
                              _selectedServiceCategory,
                              _serviceCategories,
                              Icons.work_outline_rounded,
                              (value) {
                                setModalState(() {
                                  _selectedServiceCategory = value;
                                });
                              },
                            ),
                          ],

                          const SizedBox(height: 32),

                          // Footer Button moved inside ScrollView to avoid RenderFlex Overflow
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                _applyFilters();
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 2,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'APPLIQUER LES FILTRES',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Affinez votre recherche pour trouver rapidement ce qui correspond à vos besoins",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: _darkColor,
      ),
    );
  }

  Widget _buildModernTransactionSelector() {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _buildModernTransactionOption('Location')),
          Expanded(child: _buildModernTransactionOption('Achat')),
        ],
      ),
    );
  }

  Widget _buildModernTransactionOption(String type) {
    final isSelected = _selectedTransaction == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTransaction = type;
        });
        Navigator.pop(context);
        _showFilterModal();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))] : null,
        ),
        child: Text(
          type,
          style: GoogleFonts.inter(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? _darkColor : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCategorySelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _serviceCategories.map((category) {
        final isSelected = _selectedServiceCategory == category;
        return _buildModernChip(
          label: category, 
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedServiceCategory = isSelected ? null : category;
            });
          }
        );
      }).toList(),
    );
  }

  Widget _buildModernPropertyTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _propertyTypes.map((type) {
           return Padding(
             padding: EdgeInsets.only(right: 8),
             child: _buildModernChip(
               label: type,
               isSelected: _selectedPropertyType == type,
               onTap: () {
                 setState(() {
                   _selectedPropertyType = type;
                 });
                 Navigator.pop(context);
                 _showFilterModal();
               },
             ),
           );
        }).toList(),
      ),
    );
  }

  Widget _buildModernChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
       onTap: onTap,
       child: AnimatedContainer(
         duration: Duration(milliseconds: 200),
         padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
         decoration: BoxDecoration(
           color: isSelected ? _primaryColor : Colors.white,
           borderRadius: BorderRadius.circular(30),
           border: Border.all(color: isSelected ? _primaryColor : Colors.grey.shade300),
           boxShadow: isSelected ? [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))] : null,
         ),
         child: Text(
           label,
           style: TextStyle(
             color: isSelected ? Colors.white : Colors.black87,
             fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
           ),
         ),
       ),
    );
  }

  Widget _buildModernPriceRange({StateSetter? setModalState}) {
      // Simplification: Just two inputs for now, could act as a range
    return Row(
      children: [
        Expanded(
          child: _buildModernInput(_minPriceController, 'Min', Icons.attach_money, setModalState: setModalState),
        ),
        SizedBox(width: 16),
        Text('-', style: TextStyle(color: Colors.grey, fontSize: 24)),
        SizedBox(width: 16),
        Expanded(
          child: _buildModernInput(_maxPriceController, 'Max', Icons.attach_money, setModalState: setModalState),
        ),
      ],
    );
  }

  Widget _buildModernInput(TextEditingController controller, String hint, IconData icon, {StateSetter? setModalState}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (val) {
        _updatePriceRange(setModalState: setModalState);
      },
      style: const TextStyle(
        fontSize: 15, 
        color: Color(0xFF1A1D26),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w400),
        // Icon removed per user request (trop d'icon)
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2855AE), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildModernBedroomsSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [1, 2, 3, 4, 5].map((count) {
         final label = count == 5 ? '5+' : '$count';
         final isSelected = _bedroomsController.text == count.toString();
         return _buildModernChip(
           label: '$label Ch.',
           isSelected: isSelected,
           onTap: () {
             setState(() {
                if (isSelected) {
                   _bedroomsController.clear();
                   _selectedBedrooms = null;
                } else {
                   _bedroomsController.text = count.toString();
                   _selectedBedrooms = count.toString();
                }
             });
             Navigator.pop(context);
             _showFilterModal();
           },
         );
      }).toList(),
    );
  }

  // Removed _buildSimplifiedFilterPanel implementation as it's replaced by modal
  // Keeping helper methods used in modal content below...

  Widget _buildLocationSection({StateSetter? setModalState}) {
    return Consumer<LocationController>(
      builder: (context, locationController, child) {
        if (locationController.loading && _cities.isEmpty) {
          return _buildLocationLoader();
        }

        // Use controller data as ultimate fallback if local lists are empty
        final effectiveCities = _cities.isNotEmpty ? _cities : CitySuggestions.cities;
        final effectiveCommunes = _communes.isNotEmpty ? _communes : 
          locationController.communes.map((c) => c.name ?? '').where((n) => n.isNotEmpty).toList();

        return Column(
          children: [
            LocationAutocompleteWidget(
              key: const ValueKey('city_filter_field'), // Stable key to keep focus
              hint: 'Ville',
              icon: Icons.location_city,
              suggestions: effectiveCities,
              initialValue: _selectedCity,
              onChanged: (value) => _onCityChanged(value, setModalState: setModalState),
            ),
            SizedBox(height: 14),
            LocationAutocompleteWidget(
              key: const ValueKey('commune_filter_field'), // Stable key to keep focus
              hint: _selectedCity?.trim().toLowerCase() == 'matadi' 
                  ? 'Commune (Matadi)' 
                  : (_selectedCity?.trim().toLowerCase() == 'kinshasa' ? 'Commune (Kinshasa)' : 'Commune'),
              icon: Icons.map_rounded,
              suggestions: _communes, // Use the updated _communes list
              initialValue: _selectedCommune,
              onChanged: (value) {
                final fn = () {
                  _selectedCommune = value;
                };
                setState(fn);
                if (setModalState != null) setModalState(fn);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        // Icon removed per user request (too many icons)
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.grey[600],
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationLoader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.location_on_rounded, color: _primaryColor, size: 20),
            ),
            SizedBox(width: 12),
            Text(
              'Localisation',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*Padding(
          padding: EdgeInsets.only(bottom: 6, left: 4),
          child: Text(
            hint,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),*/
        DropdownButtonFormField<String>(
          value: value,
          icon: Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF2855AE)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[500]!),
            // Icon removed per user request (trop d'icon)
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFF2855AE), width: 1.5),
            ),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text('Sélectionner $hint', style: GoogleFonts.inter(color: Colors.grey[500]!)),
            ),
            ...items.map((item) => DropdownMenuItem(
              value: item,
              child: Text(item, style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.w500)),
            )),
          ],
          onChanged: onChanged,
          dropdownColor: Colors.white,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
        ),
      ],
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: _buildSearchField(),
      centerTitle: false,
      elevation: 0,
      backgroundColor: _primaryColor,
      automaticallyImplyLeading: false,
      toolbarHeight: 70,
      actions: [
        _buildFilterBadge(),
        SizedBox(width: 16),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: _primaryColor,
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _buildTypeToggle(),
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: EdgeInsets.all(4),
      child: Row(
        children: [
          _buildToggleItem('Propriétés'),
          _buildToggleItem('Services'),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String type) {
    final bool isSelected = _searchType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _searchType = type;
            _showFilters = false; // Fermer les filtres si ouverts
          });
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            type,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? _primaryColor : Colors.white.withOpacity(0.9),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBadge() {
    final filterCount = _getActiveFilterCount();

    return Container(
      margin: EdgeInsets.only(top: 8, bottom: 8),
      child: Stack(
        children: [
          IconButton(
            icon: Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: _showFilterModal,
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
    
    // Filtres communs (Vérifier non-null et non-vide)
    if (_selectedCity != null && _selectedCity!.trim().isNotEmpty) count++;
    if (_selectedCommune != null && _selectedCommune!.trim().isNotEmpty) count++;

    if (_searchType == 'Propriétés') {
      if (_selectedPropertyType != 'Tous') count++;
      if (_selectedBedrooms != null && _selectedBedrooms!.isNotEmpty) count++;
      
      // Conversion sécurisée des prix pour comparaison
      final currentMin = double.tryParse(_minPriceController.text) ?? 10.0;
      final currentMax = double.tryParse(_maxPriceController.text) ?? 400.0;
      
      if (currentMin > 10.0 || currentMax < 400.0) count++;
      if (_selectedTransaction != 'Location') count++;
    } else {
      // Filtres Services
      if (_selectedServiceCategory != null && _selectedServiceCategory!.isNotEmpty) count++;
    }
    
    return count;
  }

  // ... (keeping _buildServiceCategoryChip string version)

  void _applyFilters() {
    setState(() {
      _visiblePropertyCount = _pageSize; 
      _visibleServiceCount = _pageSize;
    });
    
    if (_searchType == 'Propriétés') {
      // ... (keeping existing property filter logic)
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

      // Récupérer les ids
      int? cityId;
      int? communeId;

      if (_selectedCity != null) {
        final normalizedCity = _selectedCity!.trim().toLowerCase();
        final city = locationController.cities.firstWhere(
          (c) => (c.name ?? '').toLowerCase() == normalizedCity,
          orElse: () => CityModel(cityId: null),
        );
        cityId = city.cityId;
      }

      if (_selectedCommune != null) {
        final normalizedCommune = _selectedCommune!.trim().toLowerCase();
        final commune = locationController.communes.firstWhere(
          (c) => (c.name ?? '').toLowerCase() == normalizedCommune,
          orElse: () => CommuneModel(communeId: null),
        );
        communeId = commune.communeId;
      }

      int? bedrooms = _selectedBedrooms != null ? int.tryParse(_selectedBedrooms!) : null;

      // Appliquer
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
    } else {
      // Filtrage local des services
      setState(() {
        _filteredPrestations = _allPrestations.where((prestation) {
          // Filtre Catégorie
          if (_selectedServiceCategory != null) {
             final serviceName = _getServiceName(prestation.serviceId);
             if (serviceName == null) return false;
             
             if (!serviceName.toLowerCase().contains(_selectedServiceCategory!.toLowerCase()) && 
                 !_selectedServiceCategory!.toLowerCase().contains(serviceName.toLowerCase())) {
               return false;
             }
          }

          // Filtre Ville (Normalisation pour plus de robustesse)
          if (_selectedCity != null) {
            final pCity = (prestation.cityValue ?? '').trim().toLowerCase();
            final sCity = _selectedCity!.trim().toLowerCase();
            if (pCity.isNotEmpty && pCity != sCity) return false;
            // Si pCity est vide mais qu'une ville est sélectionnée, on pourrait choisir de l'exclure ou de l'inclure.
            // Généralement on exclut.
            if (pCity.isEmpty) return false; 
          }

          // Filtre Commune
          if (_selectedCommune != null) {
            final pCommune = (prestation.communeValue ?? '').trim().toLowerCase();
            final sCommune = _selectedCommune!.trim().toLowerCase();
            if (pCommune.isNotEmpty && pCommune != sCommune) return false;
            if (pCommune.isEmpty) return false;
          }
          
          return true;
        }).toList();
      });
    }

    setState(() {
      _showFilters = false;
    });
  }

  // ...
  
  // In _buildServiceListItem
  // Replace service.serviceType?.displayName with a lookup or fallback
  // Text(
  //   _getServiceName(service.serviceId) ?? "Service",
  //   style: GoogleFonts.inter(fontSize: 12, color: _primaryColor, fontWeight: FontWeight.w600),
  // ),

  String? _getServiceName(int? serviceId) {
    if (serviceId == null) return null;
    final serviceController = Provider.of<ServiceController>(context, listen: false);
    final name = serviceController.getServiceName(serviceId);
    return name != 'Prestation' ? name : null;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focusNode.hasFocus ? _primaryColor : Colors.grey[300]!,
          width: focusNode.hasFocus ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: focusNode.hasFocus
                ? _primaryColor.withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: _greyColor),
          prefixIcon: Icon(icon, color: focusNode.hasFocus ? _primaryColor : _greyColor, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          suffixText: '\$',
          suffixStyle: GoogleFonts.inter(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: GoogleFonts.inter(fontSize: 14, color: _darkColor, fontWeight: FontWeight.w500),
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
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.king_bed_rounded, color: _primaryColor, size: 20),
            ),
            SizedBox(width: 12),
            Text(
              'Nombre de chambres',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _bedroomsFocus.hasFocus ? _primaryColor : Colors.grey[300]!,
              width: _bedroomsFocus.hasFocus ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _bedroomsFocus.hasFocus
                    ? _primaryColor.withOpacity(0.1)
                    : Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _bedroomsController,
            focusNode: _bedroomsFocus,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Ex: 3',
              hintStyle: GoogleFonts.inter(color: _greyColor),
              prefixIcon: Icon(Icons.king_bed_rounded, color: _bedroomsFocus.hasFocus ? _primaryColor : _greyColor, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              suffixIcon: _bedroomsController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: _greyColor, size: 18),
                      onPressed: () {
                        setState(() {
                          _bedroomsController.clear();
                          _selectedBedrooms = null;
                        });
                      },
                    )
                  : null,
            ),
            style: GoogleFonts.inter(fontSize: 14, color: _darkColor, fontWeight: FontWeight.w500),
            onChanged: (value) {
              setState(() {
                _selectedBedrooms = value.isNotEmpty ? value : null;
              });
            },
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
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
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _primaryColor,
                    Color(0xFF64B5F6),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.king_bed_rounded,
                size: 16,
                color: isSelected ? Colors.white : _primaryColor),
            SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isSelected ? Colors.white : _darkColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construction du widget loader de bas de page
  Widget _buildBottomLoader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: _primaryColor,
          ),
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

        if (_isLoadingProperties) {
          return Center(
            child: _buildMainLoader(),
          );
        }

        // Utilise allProperties = standard + bureaux + festives + funéraires
        final allProps = controller.allProperties;

        if (controller.loading && allProps.isEmpty) {
          return Center(
            child: _buildMainLoader(),
          );
        }

        if (allProps.isEmpty) {
          return _buildEmptyState(controller);
        }

        final visibleCount = _visiblePropertyCount.clamp(0, allProps.length);
        final hasMore = visibleCount < allProps.length;

        return SmartRefresher(
          controller: _propertyRefreshController,
          enablePullDown: true,
          enablePullUp: false,
          header: WaterDropMaterialHeader(
            backgroundColor: _primaryColor,
            color: Colors.white,
          ),
          onRefresh: () async {
            // Reset pagination on refresh
            setState(() => _visiblePropertyCount = _pageSize);
            await _handlePullToRefresh(controller, controller: _propertyRefreshController);
          },
          child: ListView.builder(
            controller: _propertyScrollController,
            padding: const EdgeInsets.all(16),
            // +1 item pour le loader du bas si besoin
            itemCount: visibleCount + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == visibleCount) {
                return _isLoadingMoreProperties
                    ? _buildBottomLoader()
                    : const SizedBox.shrink();
              }
              return _buildPropertyListItem(allProps[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildServiceList() {
    // Afficher le loader de recherche
    if (_showSearchLoader) {
      return _buildSearchLoader();
    }

    if (_isLoadingServices && _filteredPrestations.isEmpty) {
      return Center(
        child: _buildMainLoader(),
      );
    }

    if (_filteredPrestations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cleaning_services_rounded, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              "Aucun service trouvé",
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _greyColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Essayez de modifier vos filtres",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    final visibleCount = _visibleServiceCount.clamp(0, _filteredPrestations.length);
    final hasMore = visibleCount < _filteredPrestations.length;

    return SmartRefresher(
      controller: _serviceRefreshController,
      enablePullDown: true,
      enablePullUp: false,
      header: WaterDropMaterialHeader(
        backgroundColor: _primaryColor,
        color: Colors.white,
      ),
      onRefresh: () async {
        // Reset pagination on refresh
        setState(() => _visibleServiceCount = _pageSize);
        final propertyCtrl = Provider.of<PropertyController>(context, listen: false);
        await _handlePullToRefresh(propertyCtrl, controller: _serviceRefreshController);
      },
      child: ListView.builder(
        controller: _serviceScrollController,
        padding: const EdgeInsets.all(16),
        itemCount: visibleCount + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == visibleCount) {
            return _isLoadingMoreServices
                ? _buildBottomLoader()
                : const SizedBox.shrink();
          }
          return _buildServiceListItem(_filteredPrestations[index]);
        },
      ),
    );
  }

  Widget _buildServiceListItem(PrestationModel service) {
    return GestureDetector(
      onTap: () {
         Navigator.pushNamed(
           context,
           Routes.serviceDetail,
           arguments: service,
         );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                    image: DecorationImage(
                      image: (service.images != null && service.images!.isNotEmpty)
                          ? CachedNetworkImageProvider(service.images!.first)
                          : AssetImage('assets/images/placeholder.png') as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getServiceName(service.serviceId) ?? "Service",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                             service.title ?? 'Service sans nom',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _darkColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      "À partir de ${service.minPrice?.toInt() ?? 0} ${service.currency}",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: _greyColor),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "${service.communeValue ?? ''}, ${service.cityValue ?? ''}",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _greyColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return _searchType == 'Propriétés' 
            ? _buildPropertyShimmerCard() 
            : _buildServiceShimmerCard();
      },
    );
  }

  Widget _buildPropertyShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 20, width: double.infinity, color: Colors.white),
                  SizedBox(height: 12),
                  Container(height: 16, width: 150, color: Colors.white),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Container(height: 24, width: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                      SizedBox(width: 12),
                      Container(height: 24, width: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
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

  Widget _buildServiceShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 20, width: double.infinity, color: Colors.white),
                  SizedBox(height: 12),
                  Container(height: 14, width: 140, color: Colors.white),
                  SizedBox(height: 16),
                  Container(height: 28, width: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                ],
              ),
            ),
          ],
        ),
      ),
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
        ? '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}/mois'
        : '${property.price?.toStringAsFixed(0) ?? '0'} ${property.currency}';

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
                        fontSize: 14,
                        color: _darkColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 4),

                    // Adresse
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: _greyColor),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "${property.cityValue}, ${property.communeValue}",
                            style: TextStyle(
                              color: _greyColor,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 6),

                    // Caractéristiques
                    Container(
                      height: 26,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          if (property.bedrooms != null)
                            _buildFeatureChip(Icons.king_bed_rounded, '${property.bedrooms} ch.'),
                          SizedBox(width: 6),
                          if (property.bathroom != null)
                            _buildFeatureChip(Icons.bathtub_rounded, '${property.bathroom} sdb'),
                          SizedBox(width: 6),
                          if (property.surface != null)
                            _buildFeatureChip(Icons.square_foot_rounded, '${property.surface}m²'),
                          if (property.rooms != null)
                            _buildFeatureChip(FontAwesomeIcons.doorClosed, '${property.rooms} pièces'),
                        ].where((element) => element != null).cast<Widget>().toList(),
                      ),
                    ),

                    SizedBox(height: 6),

                    // Prix et statut
                    Row(
                      children: [
                        Text(
                          priceText,
                          style: GoogleFonts.inter(
                            fontSize: 15,
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
      case 7: return 'Salle funéraires';
      case 8: return 'Salle de fête';
      case 9: return 'Terrain';
      case 10: return 'Entrepôt';
      default: return 'Autre';
    }
  }

  Widget _buildFeatureChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _lightColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _greyColor),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 9,
              color: _greyColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          height: 48,
          margin: EdgeInsets.only(top: 8, bottom: 8, right: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _searchController.text.isNotEmpty ? _primaryColor : Colors.grey[300]!,
              width: _searchController.text.isNotEmpty ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une ville, un quartier...',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: _greyColor),
                    prefixIcon: Icon(Icons.search_rounded, color: _searchController.text.isNotEmpty ? _primaryColor : _greyColor, size: 20),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false, // Ensure no background fill
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
                        this.setState(() {});
                        _performSearch();
                      },
                    )
                        : null,
                  ),
                  style: GoogleFonts.inter(fontSize: 14, color: _darkColor, fontWeight: FontWeight.w500),
                  onSubmitted: (value) => _performSearch(),
                  onChanged: (value) {
                    setState(() {});
                    this.setState(() {});
                    _onSearchChanged(value);
                  },
                ),
              ),

              if (_showSearchLoader)
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _primaryColor,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApplyFiltersButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _applyFilters,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Afficher les résultats',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
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
    _propertyRefreshController.dispose();
    _serviceRefreshController.dispose();
    _propertyScrollController.dispose();
    _serviceScrollController.dispose();
    super.dispose();
  }
}