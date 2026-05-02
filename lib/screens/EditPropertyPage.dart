import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/controllers/LocationController.dart';
import 'package:casa/models/CityModel.dart';
import 'package:casa/models/CommuneModel.dart';
import 'package:casa/models/DistrictModel.dart';
import 'package:casa/models/QuartierModel.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/controllers/AuthentificationCtrl.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/SubscriptionHelper.dart';
import 'package:casa/utils/Routes.dart';
import 'package:casa/utils/networkCheck.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:casa/widgets/SnackbarHelper.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:casa/utils/city_suggestions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/StockageKeys.dart';
import '../utils/property_owner_put_diff.dart';
import '../utils/requetes.dart' show HttpResponse, deleteData;
import '../utils/crashlytics_api.dart';
import 'forms/FestiveFormFields.dart';
import 'forms/FuneraireFormFields.dart';
import 'forms/VacanceFormFields.dart';

class EditPropertyPage extends StatefulWidget {
  final PropertyModel property;

  const EditPropertyPage({Key? key, required this.property}) : super(key: key);

  @override
  _EditPropertyPageState createState() => _EditPropertyPageState();
}

class _EditPropertyPageState extends State<EditPropertyPage> {
  // Couleurs Premium & Audacieuses
  final Color _primaryColor = Color(0xFF1976D2);
  final Color _secondaryColor = Color(0xFF0D47A1);
  final Color _accentColor = Color(0xFF2196F3);
  final Color _darkColor = Color(0xFF0F172A);
  final Color _lightColor = Color(0xFFF8FAFC);
  final Color _greyColor = Color(0xFF64748B);
  final Color _successColor = Color(0xFF10B981);
  final Color _warningColor = Color(0xFFF59E0B);
  final Color _errorColor = Color(0xFFEF4444);
  final Color _cardColor = Colors.white;
  final Color _borderColor = Color(0xFFE2E8F0);

  // Styles de texte
  late final TextStyle _titleStyle = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: _darkColor,
  );

  late final TextStyle _subtitleStyle = GoogleFonts.outfit(
    fontSize: 16,
    color: _greyColor,
    fontWeight: FontWeight.w500,
  );

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _guaranteeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _electricController = TextEditingController();
  final TextEditingController _bedroomsController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _livingRoomsController = TextEditingController();
  final TextEditingController _kitchensController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _roomsController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _cityTextController = TextEditingController();
  final TextEditingController _communeTextController = TextEditingController();
  final TextEditingController _quartierTextController = TextEditingController();

  // State variables
  bool _isForRent = true;
  bool _isLoading = false;
  Set<String> _selectedAmenities = {};
  LatLng? _selectedLocation;
  final ImagePicker _picker = ImagePicker();
  int _currentStep = 0;

  String? _selectedCategory;
  String? _selectedElectric;
  String? _selectedWater;
  int _selectedDeviseId = 2; // Default to USD (2)
  /// 0 = disponible, 1 = loué (location) / vendu (vente), 2 = plus disponible (retiré du catalogue)
  int _listingStatusIndex = 0;

  /// `sold` côté API pour les PUT `/property/.../sold/{id}` (location : true si loué ou plus dispo ; vente : true seulement si vendu).
  static bool _soldForApi(int statusIndex, bool isRent) {
    if (isRent) return statusIndex != 0;
    return statusIndex == 1;
  }

  bool get _apiSoldFromListingUi =>
      _soldForApi(_listingStatusIndex, _isForRent);

  Future<void> _syncSoldFlagWithFeedback(int statusIndex) async {
    final pid = widget.property.propertyId;
    if (pid == null || !mounted) return;
    final typeId =
        _getPropertyTypeId(_selectedCategory) ?? widget.property.propertyTypeId ?? 2;
    final sold = _soldForApi(statusIndex, _isForRent);
    try {
      final ctrl = Provider.of<PropertyController>(context, listen: false);
      final res = await ctrl.syncPropertySoldFlag(pid, typeId, sold: sold);
      if (!mounted) return;
      if (res.status == true) {
        SnackbarForCasa.success(
          context,
          'Statut de l’annonce mis à jour.',
        );
      } else {
        var msg = res.errorMsg ??
            'Le statut n’a pas pu être synchronisé. Réessayez dans un instant.';
        if (res.data is Map) {
          final m = Map<String, dynamic>.from(res.data as Map);
          msg = m['detailMessage']?.toString() ??
              m['message']?.toString() ??
              msg;
        }
        print('⚠️ [EditProperty] sync sold: $msg');
        SnackbarForCasa.error(context, _friendlyEditMessage(msg));
      }
    } catch (e) {
      print('⚠️ [EditProperty] sync sold: $e');
      if (mounted) {
        SnackbarForCasa.error(
          context,
          'Le statut n’a pas pu être mis à jour. Vérifiez la connexion et réessayez.',
        );
      }
    }
  }

  void _onTransactionTypeChanged(bool toRent) {
    setState(() => _isForRent = toRent);
    Future.microtask(() {
      if (!mounted) return;
      _syncSoldFlagWithFeedback(_listingStatusIndex);
    });
  }

  /// Champs spécifiques (création → même logique à l’édition)
  final TextEditingController _capacityPeopleController = TextEditingController();
  String _festiveUsage = '';
  bool _isDecore = false;
  bool _pisteDanse = false;

  final TextEditingController _vacDateController = TextEditingController();
  final TextEditingController _vacHeureController = TextEditingController();
  final TextEditingController _vacNoteController = TextEditingController();
  final TextEditingController _vacOffreController = TextEditingController();
  String? _vacPriceCombo = 'Par Nuit';

  // Location variables
  CityModel? _selectedCity;
  DistrictModel? _selectedDistrict;
  CommuneModel? _selectedCommune;
  QuartierModel? _selectedQuartier;
  bool get _isKinshasaSelected =>
      (_selectedCity?.cityId == 1) ||
      (_selectedCity?.name?.toLowerCase().trim() ?? '') == 'kinshasa' ||
      (_cityTextController.text.toLowerCase().trim() == 'kinshasa');

  List<CityModel> _availableCities = [];
  List<DistrictModel> _availableDistricts = [];
  List<CommuneModel> _availableCommunes = [];
  List<QuartierModel> _availableQuartiers = [];

  List<Map<String, dynamic>> _propertyTypes = [];
  bool _loadingTypes = false;

  // Categories d'images
  final List<ImageCategory> _imageCategories = [
    ImageCategory(
      id: 'propertyImage',
      name: 'Photos principales',
      icon: FontAwesomeIcons.home,
      color: Color(0xFF1976D2),
    ),
    ImageCategory(
      id: 'propertyImageRoom',
      name: 'Chambres',
      icon: FontAwesomeIcons.bed,
      color: Color(0xFF1976D2),
    ),
    ImageCategory(
      id: 'propertyImageLivingRoom',
      name: 'Salon',
      icon: FontAwesomeIcons.couch,
      color: Color(0xFF1976D2),
    ),
    ImageCategory(
      id: 'propertyImageKitchen',
      name: 'Cuisine',
      icon: FontAwesomeIcons.kitchenSet,
      color: Color(0xFF1976D2),
    ),
  ];

  final stockage = GetStorage();
  late final profile = stockage.read(StockageKeys.profileKey);
  late var fullname = (profile is Map) ? (profile["fullname"] ?? "Utilisateur") : "Utilisateur";

  // Images: Map pour stocker les nouvelles images (XFile) et les URLs existantes
  Map<String, List<XFile>> _newImages = {}; // Nouvelles images à uploader
  Map<String, List<String>> _existingImageUrls = {}; // URLs des images existantes

  final List<Map<String, dynamic>> _electricOptions = [
    {'value': '80', 'label': 'Élevée'},
    {'value': '60', 'label': 'Bonne'},
    {'value': '40', 'label': 'Moyenne'},
    {'value': '20', 'label': 'Faible'},
  ];

  final List<Map<String, dynamic>> _waterOptions = [
    {'value': '80', 'label': 'Excellente'},
    {'value': '60', 'label': 'Bonne'},
    {'value': '40', 'label': 'Moyenne'},
    {'value': '20', 'label': 'Faible'},
  ];

  final List<String> _amenitiesList = [
    'WiFi',
    'Climatisation',
    'Chauffage',
    'Cuisine équipée',
    'Lave-linge',
    'Parking',
    'Ascenseur',
    'Piscine',
    'Jardin',
    'Terrasse',
    'Gym',
    'Sécurité',
    'Animaux acceptés'
  ];

  final PageController _pageController = PageController();

  /// Après chargement propriété + localisation : comparaison pour PUT owner (vide si inchangé).
  _EditBaseline? _baseline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadPropertyData();
      await _loadLocationData();
      if (mounted) {
        setState(() => _captureEditBaseline());
      }
      _loadPropertyTypes();
    });
  }

  void _loadPropertyData() {
    final property = widget.property;

    // Informations de base
    _titleController.text = property.title ?? '';
    _descriptionController.text = property.description ?? '';
    _priceController.text = property.price?.toStringAsFixed(0) ?? '';
    _addressController.text = property.address ?? '';
    _postalCodeController.text = property.postalCode ?? '243';
    _areaController.text = property.surface?.toStringAsFixed(1) ?? '';
    _bedroomsController.text = property.bedrooms?.toString() ?? '';
    _bathroomsController.text = property.bathroom?.toString() ?? '';
    _livingRoomsController.text = property.livingRoom?.toString() ?? '';
    _kitchensController.text = property.kitchen?.toString() ?? '';
    _roomsController.text = property.rooms?.toString() ?? '';
    _floorController.text = property.floor?.toString() ?? '';
    _electricController.text = property.electric?.toString() ?? '';
    _guaranteeController.text = property.guarantee ?? '';

    _capacityPeopleController.text =
        property.capacityPeople != null ? '${property.capacityPeople}' : '';
    _festiveUsage = property.usage ?? '';
    _isDecore = property.isDecore ?? false;
    _pisteDanse = property.pisteDanse ?? false;
    _vacNoteController.clear();
    _vacOffreController.clear();
    _vacDateController.clear();
    _vacHeureController.clear();
    _vacPriceCombo ??= 'Par Nuit';
    final cs = property.createdStart;
    if (cs != null && cs.length >= 10) {
      _vacDateController.text = cs.substring(0, 10);
    }

    // Type de transaction
    _isForRent = property.transactionType?.toLowerCase().contains('location') ?? false;

    // Type de propriété - convertir l'ID en nom
    if (property.propertyType != null && property.propertyType?.name != null) {
      _selectedCategory = property.propertyType?.name;
    } else if (property.propertyTypeId != null) {
      final Map<int, String> typeMap = {
        1: 'Studio',
        2: 'Apparts',
        3: 'Maisons',
        4: 'Bureau',
        5: 'Hotels',
        6: 'Vacances',
        7: 'Funéraire',
        8: 'Festive',
        9: 'Terrain',
      };
      _selectedCategory = typeMap[property.propertyTypeId] ?? 'Apparts';
    }

    // Services (valeurs API 0 ou hors 20/40/60/80 → pas de sélection pour éviter crash Dropdown)
    _selectedElectric = _normalizeElectricWaterOption(property.electric);
    _selectedWater = _normalizeElectricWaterOption(property.water);

    // Statut initial : **uniquement `sold`**, pas `isActive`.
    // Location : sold==true → plus disponible (2), sinon disponible (0).
    // Vente : sold==true → vendu (1), sinon disponible (0). « Loué » / « plus dispo » ne sont pas déduits de l’API sans sold.
    final isRent =
        property.transactionType?.toLowerCase().contains('location') ?? false;
    if (isRent) {
      _listingStatusIndex = property.sold == true ? 2 : 0;
    } else {
      _listingStatusIndex = property.sold == true ? 1 : 0;
    }

    // Features/Amenities
    if (property.features != null && property.features!.isNotEmpty) {
      _selectedAmenities = property.features!
          .map((f) => f.name ?? '')
          .where((name) => name.isNotEmpty)
          .toSet();
    }

    // Coordonnées GPS
    if (property.latitude != null && property.longitude != null) {
      _selectedLocation = LatLng(property.latitude!, property.longitude!);
    }

    // Location textuelle
    _cityTextController.text = property.cityValue ?? '';
    _communeTextController.text = property.communeValue ?? '';
    _quartierTextController.text = property.quartierValue ?? '';
    _selectedDeviseId = property.deviseId ?? 2;

    // Images existantes (URLs)
    _existingImageUrls['propertyImage'] = property.propertyImage
            ?.map((img) => img.path ?? '')
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];
    _existingImageUrls['propertyImageRoom'] = property.propertyImageRoom
            ?.map((img) => img.path ?? '')
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];
    _existingImageUrls['propertyImageLivingRoom'] = property.propertyImageLivingRoom
            ?.map((img) => img.path ?? '')
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];
    _existingImageUrls['propertyImageKitchen'] = property.propertyImageKitchen
            ?.map((img) => img.path ?? '')
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];

    // Initialiser les nouvelles images
    _imageCategories.forEach((category) {
      _newImages[category.id] = [];
    });

    setState(() {});
  }

  /// Valeurs attendues par les dropdowns Électricité / Eau (évite tag `0` absent de la liste).
  String? _normalizeElectricWaterOption(int? apiValue) {
    const allowed = {'80', '60', '40', '20'};
    if (apiValue == null) return null;
    final s = apiValue.toString();
    return allowed.contains(s) ? s : null;
  }

  int? get _effectivePropertyTypeId => _getPropertyTypeId(_selectedCategory);

  /// Même logique que la création : certains types n’ont que des photos principales.
  List<ImageCategory> get _visibleImageCategories {
    final tid = _effectivePropertyTypeId;
    final name =
        (_selectedCategory ?? widget.property.propertyType?.name ?? '').toLowerCase();
    final onlyMain = tid == 9 ||
        tid == 8 ||
        tid == 7 ||
        tid == 6 ||
        tid == 5 ||
        tid == 4 ||
        name.contains('terrain') ||
        name.contains('festive') ||
        name.contains('fête') ||
        name.contains('funéra') ||
        name.contains('funer') ||
        name.contains('deuil') ||
        name.contains('vacances') ||
        name.contains('hotel') ||
        name.contains('hôtel') ||
        name.contains('bureau');
    if (onlyMain) {
      return _imageCategories.where((c) => c.id == 'propertyImage').toList();
    }
    return List<ImageCategory>.from(_imageCategories);
  }

  bool get _hideEssentialServicesRow {
    final tid = _effectivePropertyTypeId;
    final name = (_selectedCategory ?? '').toLowerCase();
    if (tid == 9 || name.contains('terrain')) return true;
    if (tid == 6 || name.contains('vacances')) return true;
    if (tid == 5 || name.contains('hotel') || name.contains('hôtel')) return true;
    return false;
  }

  bool get _isFestiveEditType {
    final tid = _effectivePropertyTypeId;
    if (tid == 8) return true;
    final n = (_selectedCategory ?? widget.property.propertyType?.name ?? '').toLowerCase();
    return n.contains('fête') || n.contains('fete') || n.contains('festive');
  }

  bool get _isFuneraireEditType {
    final tid = _effectivePropertyTypeId;
    if (tid == 7) return true;
    final n = (_selectedCategory ?? '').toLowerCase();
    return n.contains('funér') || n.contains('funer');
  }

  bool get _isVacancesEditType {
    final tid = _effectivePropertyTypeId;
    if (tid == 6) return true;
    final n = (_selectedCategory ?? '').toLowerCase();
    return n.contains('vacance');
  }

  bool get _isBureauEditType {
    final tid = _effectivePropertyTypeId;
    if (tid == 4) return true;
    final n = (_selectedCategory ?? '').toLowerCase();
    return n.contains('bureau');
  }

  bool get _isTerrainEditType {
    final tid = _effectivePropertyTypeId;
    if (tid == 9) return true;
    final n = (_selectedCategory ?? '').toLowerCase();
    return n.contains('terrain');
  }

  /// Garantie : logique alignée sur CreatePropertyPostPage.
  bool get _showGuaranteeField {
    if (!_isForRent) return false;
    if (_isVacancesEditType || _isBureauEditType || _isTerrainEditType ||
        _isFestiveEditType || _isFuneraireEditType) {
      return false;
    }
    return true;
  }

  /// Pas de « /mois » pour séjours / salles / hôtel / terrain.
  bool get _hideMonthlyPriceSuffix =>
      _isFestiveEditType ||
      _isFuneraireEditType ||
      _isVacancesEditType ||
      _isTerrainEditType ||
      _effectivePropertyTypeId == 5;

  bool get _hideResidentialSpacesSection =>
      _isFestiveEditType ||
      _isFuneraireEditType ||
      _isVacancesEditType ||
      _isTerrainEditType;

  Future<void> _loadLocationData() async {
    final locationCtrl = Provider.of<LocationController>(context, listen: false);

    await locationCtrl.getAllCities();
    _availableCities = locationCtrl.cities;

    final isKinshasa = widget.property.cityValue?.toLowerCase().trim() == 'kinshasa' ||
        widget.property.cityId == 1;

    if (isKinshasa) {
      try {
        _selectedCity = _availableCities.firstWhere(
          (c) => c.cityId == 1 || (c.name?.toLowerCase().trim() == 'kinshasa'),
        );

        await locationCtrl.getAllDistricts();
        _availableDistricts = locationCtrl.getDistrictsForCity(1);

        await locationCtrl.getAllCommunes();
        final allCommunes = locationCtrl.communes;

        CommuneModel? resolvedCommune;
        if (widget.property.communeId != null) {
          try {
            resolvedCommune = allCommunes.firstWhere(
              (c) => c.communeId == widget.property.communeId,
            );
          } catch (_) {
            print("Commune id ${widget.property.communeId} introuvable dans le référentiel");
          }
        }
        if (resolvedCommune == null &&
            widget.property.communeValue != null &&
            widget.property.communeValue!.trim().isNotEmpty) {
          final target = widget.property.communeValue!.toLowerCase().trim();
          try {
            resolvedCommune = allCommunes.firstWhere(
              (c) => (c.name ?? '').toLowerCase().trim() == target,
            );
          } catch (_) {}
        }

        if (resolvedCommune != null) {
          _selectedCommune = resolvedCommune;
          final did = resolvedCommune.district?.districtId;
          if (did != null) {
            try {
              _selectedDistrict = _availableDistricts.firstWhere(
                (d) => d.districtId == did,
              );
            } catch (_) {
              print("District $did non trouvé pour la commune");
            }
            _availableCommunes = locationCtrl.getCommunesForDistrict(did);
          } else {
            final distIds = _availableDistricts.map((d) => d.districtId).whereType<int>().toSet();
            _availableCommunes = allCommunes
                .where((c) =>
                    c.district?.districtId != null &&
                    distIds.contains(c.district!.districtId))
                .toList();
            if (_availableCommunes.isEmpty) {
              _availableCommunes = List<CommuneModel>.from(allCommunes);
            }
          }
        } else {
          final distIds = _availableDistricts.map((d) => d.districtId).whereType<int>().toSet();
          _availableCommunes = allCommunes
              .where((c) =>
                  c.district?.districtId != null &&
                  distIds.contains(c.district!.districtId))
              .toList();
          if (_availableCommunes.isEmpty) {
            _availableCommunes = List<CommuneModel>.from(allCommunes);
          }
        }

        if (widget.property.quartierId != null && _selectedCommune?.communeId != null) {
          await locationCtrl.getAllQuartiers();
          _availableQuartiers =
              locationCtrl.getQuartiersForCommune(_selectedCommune!.communeId!);
          try {
            _selectedQuartier = _availableQuartiers.firstWhere(
              (q) => q.quartierId == widget.property.quartierId,
            );
          } catch (e) {
            print("Quartier non trouvé: ${widget.property.quartierId}");
          }
        }
      } catch (e) {
        print("Ville Kinshasa non trouvée dans le référentiel: $e");
      }
    } else {
      _selectedCity = null;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _captureEditBaseline() {
    final p = widget.property;
    final electricR = _hideEssentialServicesRow
        ? (p.electric ?? 0)
        : (int.tryParse(_selectedElectric ?? '') ?? 60);
    var waterR = _hideEssentialServicesRow
        ? (p.water ?? 0)
        : (int.tryParse(_selectedWater ?? '') ?? 60);
    if (!_hideEssentialServicesRow && waterR < 1) {
      waterR = electricR >= 1 ? electricR : 60;
    }

    final effCity = _isKinshasaSelected && _selectedCity?.cityId != null
        ? _selectedCity!.cityId!
        : (p.cityId ?? 1);
    final effCommune = _isKinshasaSelected && _selectedCommune?.communeId != null
        ? _selectedCommune!.communeId
        : p.communeId;
    final effQuartier = _isKinshasaSelected && _selectedQuartier?.quartierId != null
        ? _selectedQuartier!.quartierId
        : p.quartierId;

    final communeVal = _isKinshasaSelected
        ? (_selectedCommune?.name ?? '').trim()
        : _communeTextController.text.trim();
    final quartierVal = _isKinshasaSelected
        ? (_selectedQuartier?.name ?? '').trim()
        : _quartierTextController.text.trim();
    final cityVal = _isKinshasaSelected ? 'Kinshasa' : _cityTextController.text.trim();

    _baseline = _EditBaseline(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      address: _addressController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      areaText: _areaController.text.trim(),
      cityValueResolved: cityVal,
      communeValueResolved: communeVal,
      quartierValueResolved: quartierVal,
      countryValueResolved: 'RDC',
      festiveUsage: _festiveUsage.trim(),
      capacityPeopleText: _capacityPeopleController.text.trim(),
      roomsText: _roomsController.text.trim(),
      isForRent: _isForRent,
      listingStatusIndex: _listingStatusIndex,
      selectedDeviseId: _selectedDeviseId,
      propertyTypeId: _getPropertyTypeId(_selectedCategory) ?? p.propertyTypeId ?? 2,
      selectedElectric: _selectedElectric,
      selectedWater: _selectedWater,
      isDecore: _isDecore,
      pisteDanse: _pisteDanse,
      latitude: _selectedLocation?.latitude ?? p.latitude,
      longitude: _selectedLocation?.longitude ?? p.longitude,
      effectiveCityId: effCity,
      effectiveCommuneId: effCommune,
      effectiveQuartierId: effQuartier,
      electricResolved: electricR,
      waterResolved: waterR,
      mainImageUrls: List<String>.from(_existingImageUrls['propertyImage'] ?? []),
      roomMeet: p.roomMeet ?? 0,
      numberPiece: p.numberPiece ?? 0,
      isEquip: p.isEquip ?? false,
      baselinePrice: double.tryParse(_priceController.text) ?? p.price ?? 0.0,
    );
  }

  PropertyModel get property => widget.property;


  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _guaranteeController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _electricController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _livingRoomsController.dispose();
    _kitchensController.dispose();
    _areaController.dispose();
    _floorController.dispose();
    _roomsController.dispose();
    _postalCodeController.dispose();
    _cityTextController.dispose();
    _communeTextController.dispose();
    _quartierTextController.dispose();
    _capacityPeopleController.dispose();
    _vacDateController.dispose();
    _vacHeureController.dispose();
    _vacNoteController.dispose();
    _vacOffreController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: _buildProgressIndicator(),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _buildCurrentStep(),
                ),
              ),
            ),
          ),
          // Espace pour le bouton du bas
          SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom == 0 
          ? _buildBottomActionBar() 
          : null,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: _primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: _currentStep == 0 ? 56 : 20, bottom: 16),
        title: Text(
          'Modifier l\'annonce',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Icon(Icons.edit_note_rounded, size: 200, color: Colors.white10),
              ),
            ],
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.fromLTRB(25, 20, 25, 10),
      child: Column(
        children: [
          Row(
            children: [
              _buildProgressStep(0, "Photos", Icons.photo_library_outlined),
              _buildProgressLine(0),
              _buildProgressStep(1, "Infos", Icons.info_outline_rounded),
              _buildProgressLine(1),
              _buildProgressStep(2, "Lieu", Icons.location_on_outlined),
            ],
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStepLabel(0, "Photos"),
                _buildStepLabel(1, "Détails"),
                _buildStepLabel(2, "Localisation"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String title, IconData icon) {
    bool isActive = _currentStep == step;
    bool isCompleted = _currentStep > step;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isActive ? _primaryColor : (isCompleted ? _successColor : Colors.white),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive || isCompleted ? Colors.transparent : _borderColor,
          width: 2,
        ),
        boxShadow: isActive ? [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ] : null,
      ),
      child: Center(
        child: Icon(
          isCompleted ? Icons.check_rounded : icon,
          size: 18,
          color: isActive || isCompleted ? Colors.white : _greyColor,
        ),
      ),
    );
  }

  Widget _buildProgressLine(int step) {
    bool isCompleted = _currentStep > step;
    return Expanded(
      child: Container(
        height: 3,
        margin: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isCompleted ? _successColor : _borderColor,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildStepLabel(int step, String label) {
    bool isActive = _currentStep == step;
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        color: isActive ? _primaryColor : _greyColor,
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildStep0();
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      default: return _buildStep0();
    }
  }

  Widget _buildBottomActionBar() {
    // Obtenir la hauteur de la barre de navigation système
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    
    return Container(
      padding: EdgeInsets.fromLTRB(20, 15, 20, 30 + bottomPadding), // Ajouter le padding pour la barre de navigation
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: Offset(0, -5))
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Container(
              margin: EdgeInsets.only(right: 12),
              child: IconButton(
                onPressed: () {
                   setState(() {
                    _currentStep--;
                  });
                },
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: _primaryColor),
                style: IconButton.styleFrom(
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  padding: EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          Expanded(
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: _isLoading ? null : LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 6)
                  )
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : (_currentStep < 2 ? () => setState(() => _currentStep++) : _handleUpdate),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: _isLoading ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _currentStep < 2 ? "Continuer" : "Enregistrer",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernSectionHeader(
          icon: Icons.photo_camera_rounded,
          title: 'Gestion des visuels',
          subtitle: 'Les annonces avec photos sont 5x plus consultées',
        ),
        SizedBox(height: 25),
        ..._visibleImageCategories.map((category) => _buildModernImageCategorySection(category)),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernSectionHeader(
          icon: Icons.info_outline_rounded,
          title: 'Informations de base',
          subtitle: 'Définissez le type de transaction et les détails',
        ),
        SizedBox(height: 25),
        
        Text(
          "Type de transaction",
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: _darkColor),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAudaciousTypeCard(
                title: "À louer",
                subtitle: "Location",
                isSelected: _isForRent,
                iconPath: Icons.key_rounded,
                onTap: () => _onTransactionTypeChanged(true),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildAudaciousTypeCard(
                title: "À vendre",
                subtitle: "Vente directe",
                isSelected: !_isForRent,
                iconPath: Icons.sell_rounded,
                onTap: () => _onTransactionTypeChanged(false),
              ),
            ),
          ],
        ),

        SizedBox(height: 25),
        _buildListingStatusSection(),

        SizedBox(height: 25),
        _buildSectionHeader(
          icon: Icons.notes_rounded,
          title: 'Description',
        ),
        SizedBox(height: 16),
        _buildModernTextField(_titleController, 'Titre accrocheur', Icons.title_rounded, isRequired: true),
        SizedBox(height: 16),
        _buildModernTextField(_descriptionController, 'Description complète', Icons.description_rounded,
            maxLines: 4, isRequired: true),
            
        SizedBox(height: 25),
        _buildSectionHeader(
          icon: Icons.payments_outlined,
          title: 'Aspects financiers',
        ),
        SizedBox(height: 16),
        _buildModernTextField(
            _priceController,
            'Prix (${_isForRent && !_hideMonthlyPriceSuffix ? "\$/mois" : "\$"})',
            Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
            isRequired: true),
        
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDeviseOption(
                label: 'FC (Franc Congolais)',
                value: 1,
                isSelected: _selectedDeviseId == 1,
                onTap: () => setState(() => _selectedDeviseId = 1),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildDeviseOption(
                label: '\$ (Dollar US)',
                value: 2,
                isSelected: _selectedDeviseId == 2,
                onTap: () => setState(() => _selectedDeviseId = 2),
              ),
            ),
          ],
        ),

        if (_showGuaranteeField) ...[
          SizedBox(height: 16),
          _buildModernTextField(_guaranteeController, 'Mois de garantie', Icons.security_rounded,
              keyboardType: TextInputType.number),
        ],
        
        SizedBox(height: 25),
        _buildSectionHeader(
          icon: Icons.home_work_outlined,
          title: 'Type de bien',
        ),
        SizedBox(height: 16),
        _buildPropertyTypeSelector(),

        if (_isFestiveEditType) ...[
          SizedBox(height: 25),
          FestiveFormFields(
            capacityController: _capacityPeopleController,
            initUsage: _festiveUsage.isNotEmpty ? _festiveUsage : widget.property.usage,
            isDecore: _isDecore,
            pisteDanse: _pisteDanse,
            onUsageChanged: (s) => setState(() => _festiveUsage = (s ?? '').trim()),
            onDecoreChanged: (v) => setState(() => _isDecore = v),
            onPisteDanseChanged: (v) => setState(() => _pisteDanse = v),
          ),
        ],
        if (_isFuneraireEditType && !_isFestiveEditType) ...[
          SizedBox(height: 25),
          FuneraireFormFields(capacityController: _capacityPeopleController),
        ],
        if (_isVacancesEditType && !_isFestiveEditType && !_isFuneraireEditType) ...[
          SizedBox(height: 25),
          VacanceFormFields(
            dateController: _vacDateController,
            heureController: _vacHeureController,
            capacityController: _capacityPeopleController,
            noteController: _vacNoteController,
            offreController: _vacOffreController,
            selectedPriceCombo: _vacPriceCombo,
            onPriceComboChanged: (v) => setState(() => _vacPriceCombo = v),
          ),
        ],
        
        if (!_hideResidentialSpacesSection) ...[
          SizedBox(height: 25),
          _buildSectionHeader(
            icon: Icons.straighten_rounded,
            title: 'Espaces & Dimensions',
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildModernTextField(_areaController, 'Surface m²', Icons.square_foot_rounded,
                  keyboardType: TextInputType.number)),
              SizedBox(width: 16),
              Expanded(child: _buildModernTextField(_roomsController, 'Pièces', Icons.meeting_room_rounded,
                  keyboardType: TextInputType.number)),
            ],
          ),
          SizedBox(height: 16),
          if (_effectivePropertyTypeId != 9) ...[
            Row(
              children: [
                Expanded(child: _buildModernTextField(_bedroomsController, 'Chambres', Icons.bed_rounded,
                    keyboardType: TextInputType.number)),
                SizedBox(width: 16),
                Expanded(child: _buildModernTextField(_bathroomsController, 'Salles de bain',
                    Icons.bathroom_rounded, keyboardType: TextInputType.number)),
              ],
            ),
            SizedBox(height: 16),
          ],
        ],
        
        SizedBox(height: 30),
        if (!_hideEssentialServicesRow) ...[
          _buildModernSectionHeader(
            icon: Icons.checklist_rounded,
            title: 'Services & Équipements',
            subtitle: 'Améliorez l\'attractivité de votre bien',
          ),
          SizedBox(height: 16),
          _buildElectricWaterSelector(),
          SizedBox(height: 20),
          _buildAmenitiesSection(),
        ],
      ],
    );
  }

  Widget _buildListingStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(icon: Icons.storefront_outlined, title: 'Statut de l\'annonce'),
        SizedBox(height: 8),
        Text(
          _isForRent
              ? 'Uniquement le champ « sold » côté API : location avec sold=true → plus disponible ; sold=false → disponible. Loué envoie aussi sold=true.'
              : 'Uniquement « sold » : vendu si sold=true, disponible si sold=false. Plus disponible (hors catalogue) envoie sold=false.',
          style: GoogleFonts.outfit(fontSize: 12, color: _greyColor, height: 1.35),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(
                'Disponible',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: _listingStatusIndex == 0 ? _successColor : _darkColor,
                ),
              ),
              selected: _listingStatusIndex == 0,
              selectedColor: _successColor.withOpacity(0.22),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _listingStatusIndex == 0 ? _successColor : _borderColor,
                width: _listingStatusIndex == 0 ? 2 : 1,
              ),
              onSelected: (sel) {
                if (!sel) return;
                setState(() => _listingStatusIndex = 0);
                _syncSoldFlagWithFeedback(0);
              },
            ),
            ChoiceChip(
              label: Text(
                _isForRent ? 'Loué' : 'Vendu',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: _listingStatusIndex == 1 ? _primaryColor : _darkColor,
                ),
              ),
              selected: _listingStatusIndex == 1,
              selectedColor: _primaryColor.withOpacity(0.2),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _listingStatusIndex == 1 ? _primaryColor : _borderColor,
                width: _listingStatusIndex == 1 ? 2 : 1,
              ),
              onSelected: (sel) {
                if (!sel) return;
                setState(() => _listingStatusIndex = 1);
                _syncSoldFlagWithFeedback(1);
              },
            ),
            ChoiceChip(
              label: Text(
                'Plus disponible',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: _listingStatusIndex == 2 ? _errorColor : _darkColor,
                ),
              ),
              selected: _listingStatusIndex == 2,
              selectedColor: _errorColor.withOpacity(0.15),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _listingStatusIndex == 2 ? _errorColor : _borderColor,
                width: _listingStatusIndex == 2 ? 2 : 1,
              ),
              onSelected: (sel) {
                if (!sel) return;
                setState(() => _listingStatusIndex = 2);
                _syncSoldFlagWithFeedback(2);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernSectionHeader(
          icon: Icons.location_on_rounded,
          title: 'Emplacement',
          subtitle: 'La localisation exacte aide les clients à se projeter',
        ),
        SizedBox(height: 25),
        _buildModernTextField(_addressController, 'Adresse physique exact', Icons.home_rounded,
            isRequired: true),
        SizedBox(height: 20),
        
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primaryColor.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              if (_isKinshasaSelected) ...[
                _buildModernLocationDropdown<CityModel>(
                  'Ville',
                  _selectedCity,
                  _availableCities,
                  (city) => city.name ?? '',
                  (city) async {
                    setState(() { _selectedCity = city; _selectedDistrict = null; _selectedCommune = null; _selectedQuartier = null; });
                    if (city?.name?.toLowerCase() == 'kinshasa') _loadDistricts();
                  },
                  Icons.location_city_rounded,
                ),
                if (_selectedCity != null) ...[
                  SizedBox(height: 12),
                  _buildModernLocationDropdown<DistrictModel>(
                    'District', _selectedDistrict, _availableDistricts, (d) => d.name ?? '',
                    (d) async { setState(() { _selectedDistrict = d; _selectedCommune = null; _selectedQuartier = null; }); await _loadCommunes(); },
                    Icons.map_rounded,
                  ),
                ],
                if (_selectedDistrict != null) ...[
                  SizedBox(height: 12),
                  _buildModernLocationDropdown<CommuneModel>(
                    'Commune', _selectedCommune, _availableCommunes, (c) => c.name ?? '',
                    (c) async { setState(() { _selectedCommune = c; _selectedQuartier = null; }); await _loadQuartiers(); },
                    Icons.location_on_rounded,
                  ),
                ],
                if (_selectedCommune != null) ...[
                  SizedBox(height: 12),
                  _buildModernLocationDropdown<QuartierModel>(
                    'Quartier', _selectedQuartier, _availableQuartiers, (q) => q.name ?? '',
                    (q) => setState(() => _selectedQuartier = q),
                    Icons.place_rounded,
                  ),
                ],
              ] else ...[
                _buildModernTextField(_cityTextController, 'Ville', Icons.location_city_rounded),
                SizedBox(height: 12),
                _buildModernTextField(_communeTextController, 'Commune', Icons.map_rounded),
                SizedBox(height: 12),
                _buildModernTextField(_quartierTextController, 'Quartier', Icons.place_rounded),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernSectionHeader({required IconData icon, required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _primaryColor, size: 24),
            ),
            SizedBox(width: 12),
            Text(title, style: _titleStyle.copyWith(fontSize: 20)),
          ],
        ),
        SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Text(subtitle, style: _subtitleStyle.copyWith(fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: _primaryColor, size: 20),
        SizedBox(width: 10),
        Text(
          title, 
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: _darkColor.withOpacity(0.8))
        ),
      ],
    );
  }

  Widget _buildModernTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool isRequired = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w500,
          color: Colors.black87, // Force black text on white background
        ),
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          labelStyle: GoogleFonts.outfit(color: _greyColor, fontSize: 14),
          prefixIcon: Icon(icon, color: _primaryColor, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: isRequired ? (v) => v == null || v.isEmpty ? 'Champ requis' : null : null,
      ),
    );
  }

  Widget _buildAudaciousTypeCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData iconPath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        height: 80,
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _primaryColor : _borderColor, width: 2),
          boxShadow: isSelected ? [
            BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 6))
          ] : null,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white24 : _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(iconPath, color: isSelected ? Colors.white : _primaryColor, size: 22),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.white : _darkColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.white70 : _greyColor,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyTypeSelector() {
    if (_loadingTypes) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }

    if (_propertyTypes.isEmpty) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        child: Text('Aucun type de propriété disponible', style: TextStyle(color: _greyColor)),
      );
    }

    final categories = _propertyTypes.where((type) {
      final typeName = type['name']?.toString().toLowerCase();
      // Types "Basiques" pour Commissionnaire/Bailleur (incluant Terrain)
      final isBasicType = ['studio', 'apparts', 'maisons', 'bureau', 'terrain', 'terrains'].contains(typeName);
      
      final userAccounts = stockage.read('user_accounts');
      bool isGerant = false;
      bool isSimpleProprietaire = false;

      if (userAccounts != null && userAccounts is List) {
        isGerant = userAccounts.any((acc) {
           final typeId = (acc['typeAccount']?['typeAccountId'] ?? (acc['typeAccountId'] ?? acc['TypeAccountId']));
           final name = (acc['name'] ?? acc['Name'])?.toString().toLowerCase() ?? '';
           return typeId == 2 && (name.contains('gerant') || acc['id'] == 3);
        });
        
        isSimpleProprietaire = userAccounts.any((acc) {
          final typeId = (acc['typeAccount']?['typeAccountId'] ?? (acc['typeAccountId'] ?? acc['TypeAccountId']));
          final name = (acc['name'] ?? acc['Name'])?.toString().toLowerCase() ?? '';
          return typeId == 2 && !name.contains('gerant');
        });
      }

      if (isGerant && isSimpleProprietaire) return true;
      if (isGerant && !isSimpleProprietaire) return !isBasicType;
      if (isSimpleProprietaire && !isGerant) return isBasicType;
      
      return true;
    }).map((type) {
      IconData icon;
      final typeName = type['name']?.toString() ?? '';
      
      switch (typeName.toLowerCase()) {
        case 'studio': icon = Icons.apartment_rounded; break;
        case 'apparts': icon = Icons.home_work_rounded; break;
        case 'maisons': icon = Icons.house_rounded; break;
        case 'bureau': icon = Icons.business_center_rounded; break;
        case 'hotels': icon = Icons.hotel_rounded; break;
        case 'vacances': icon = Icons.beach_access_rounded; break;
        case 'terrain': case 'terrains': icon = Icons.map_rounded; break;
        case 'fête': case 'fêtes': case 'festive': case 'salle de fête': icon = Icons.celebration_rounded; break;
        case 'funérariams': case 'funérailles': case 'deuil': case 'salle de deuil': case 'funéraire': icon = Icons.church_rounded; break;
        default: icon = Icons.home_rounded;
      }

      return {
        'id': type['propertyTypeId'],
        'name': typeName,
        'label': typeName == 'Apparts' ? 'Appartement' : typeName,
        'icon': icon,
      };
    }).toList();

    return Container(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 12),
        itemBuilder: (context, index) {
          final c = categories[index];
          final typeName = c['name'] as String;
          final sel = _selectedCategory == typeName;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = typeName),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 85,
              decoration: BoxDecoration(
                color: sel ? _primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: sel ? _primaryColor : _borderColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(c['icon'] as IconData, color: sel ? Colors.white : _primaryColor, size: 24),
                  SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      c['label'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12, 
                        fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                        color: sel ? Colors.white : _darkColor
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadPropertyTypes() async {
    if (!mounted) return;
    setState(() => _loadingTypes = true);

    try {
      final propertyCtrl = Provider.of<PropertyController>(context, listen: false);
      final types = await propertyCtrl.getPropertyTypes();
      
      if (mounted) {
        setState(() {
          _propertyTypes = types;
          _loadingTypes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingTypes = false);
      }
    }
  }

  Widget _buildElectricWaterSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildModernLocationDropdown<String>(
            'Électricité', _selectedElectric, _electricOptions.map((e) => e['value'] as String).toList(),
            (v) => _electricOptions.firstWhere((e) => e['value'] == v)['label'],
            (v) => setState(() => _selectedElectric = v),
            Icons.bolt_rounded,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildModernLocationDropdown<String>(
            'Eau', _selectedWater, _waterOptions.map((e) => e['value'] as String).toList(),
            (v) => _waterOptions.firstWhere((e) => e['value'] == v)['label'],
            (v) => setState(() => _selectedWater = v),
            Icons.water_drop_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildAmenitiesSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _amenitiesList.map((amenity) {
        final isSelected = _selectedAmenities.contains(amenity);
        return FilterChip(
          label: Text(amenity),
          selected: isSelected,
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
          checkmarkColor: _primaryColor,
        );
      }).toList(),
    );
  }

  Widget _buildModernImageCategorySection(ImageCategory category) {
    final existingUrls = _existingImageUrls[category.id] ?? [];
    final newImages = _newImages[category.id] ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(category.icon, color: _primaryColor, size: 18),
              ),
              SizedBox(width: 12),
              Text(category.name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: _darkColor)),
              Spacer(),
              Text("${existingUrls.length + newImages.length} photos", style: GoogleFonts.outfit(fontSize: 12, color: _greyColor)),
            ],
          ),
          SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Bouton AJOUTER au début
                GestureDetector(
                  onTap: () => _pickImages(category.id),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _primaryColor.withOpacity(0.2), style: BorderStyle.none),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded, color: _primaryColor, size: 30),
                        SizedBox(height: 4),
                        Text("Ajouter", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryColor)),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Nouvelles images
                ...newImages.asMap().entries.map((e) => _buildImageThumbnail(File(e.value.path), isFile: true, onDelete: () {
                  setState(() { _newImages[category.id]!.removeAt(e.key); });
                })),
                // Images existantes
                ...existingUrls.asMap().entries.map((e) => _buildImageThumbnail(e.value, isFile: false, onDelete: () {
                  _handleExistingImageDeletion(category.id, e.value, e.key);
                })),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(dynamic source, {bool isFile = false, VoidCallback? onDelete}) {
    return Container(
      margin: EdgeInsets.only(right: 12),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: isFile ? Image.file(source as File, fit: BoxFit.cover, width: 100, height: 100)
                : CachedNetworkImage(imageUrl: source as String, fit: BoxFit.cover, width: 100, height: 100),
          ),
          if (onDelete != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.close_rounded, color: _errorColor, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickImages(String categoryId) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 85);
      if (images.isNotEmpty) {
        setState(() {
          _newImages[categoryId]!.addAll(images);
        });
      }
    } catch (e) {
      FancyNotification.show(
        context,
        'Les photos n’ont pas pu être ajoutées. Réessayez ou choisissez d’autres fichiers.',
        type: NotificationType.error,
      );
    }
  }

  Widget _buildModernLocationDropdown<T>(
    String label, T? val, List<T> items, String Function(T) getLab, Function(T?) onChanged, IconData icon
  ) {
    T? safeVal = val;
    if (val != null) {
      final matches = items.where((i) => i == val).length;
      if (matches != 1) safeVal = null;
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonFormField<T>(
        value: safeVal,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: _greyColor, fontSize: 13),
          prefixIcon: Icon(icon, color: _primaryColor, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(getLab(i), style: GoogleFonts.outfit(fontSize: 14)))).toList(),
        onChanged: onChanged,
        icon: Icon(Icons.expand_more_rounded, color: _greyColor),
      ),
    );
  }

  Widget _buildDeviseOption({required String label, required int value, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.05) : _lightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryColor : _borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? _primaryColor : _greyColor,
            ),
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _buildOwnerPutMainImagesPayload() async {
    final b = _baseline;
    final urls = List<String>.from(_existingImageUrls['propertyImage'] ?? []);
    final news = _newImages['propertyImage'] ?? [];
    final baseUrls = b?.mainImageUrls ?? [];
    if (PropertyOwnerPutDiff.listStrEquals(urls, baseUrls) && news.isEmpty) {
      return <Map<String, dynamic>>[{'image': ''}];
    }
    final out = <Map<String, dynamic>>[];
    for (final u in urls) {
      if (u.isNotEmpty) out.add({'image': u});
    }
    for (final f in news) {
      try {
        final file = File(f.path);
        if (await file.exists()) {
          out.add({'image': base64Encode(await file.readAsBytes())});
        }
      } catch (_) {}
    }
    if (out.isEmpty) return <Map<String, dynamic>>[{'image': ''}];
    return out;
  }

  List<Map<String, String>> _buildImageNameOldPairs() {
    final b = _baseline;
    if (b == null) return [];
    final base = b.mainImageUrls;
    final cur = _existingImageUrls['propertyImage'] ?? [];
    final news = _newImages['propertyImage'] ?? [];
    final removed = base.where((u) => u.isNotEmpty && !cur.contains(u)).toList();
    if (removed.isEmpty || news.isEmpty) return [];
    final n = removed.length < news.length ? removed.length : news.length;
    final out = <Map<String, String>>[];
    for (var i = 0; i < n; i++) {
      final name = news[i].path.replaceAll('\\', '/').split('/').last;
      out.add({'name': name, 'old': removed[i]});
    }
    return out;
  }

  /// Terrain : uniquement remplacements (name/old). Festive / funéraire / bureau : remplacements + fichiers ajoutés (`old` vide).
  Future<void> _putOwnerImageEndpointsAfterSuccess(PropertyController ctrl, int id, int typeId) async {
    if (typeId != 4 && typeId != 7 && typeId != 8 && typeId != 9) return;

    final pairs = _buildImageNameOldPairs();
    final extras = _newImages['propertyImage'] ?? [];
    final skip = pairs.length;
    final additions = <Map<String, String>>[];
    for (var i = skip; i < extras.length; i++) {
      additions.add({
        'name': extras[i].path.replaceAll('\\', '/').split('/').last,
        'old': '',
      });
    }

    if (typeId == 9) {
      if (pairs.isEmpty) return;
      final r = await ctrl.updateTerrainImages(id, pairs);
      if (!r.status) print('⚠️ PUT images terrain (name/old): ${r.errorMsg}');
      return;
    }

    final all = <Map<String, String>>[...pairs, ...additions];
    if (all.isEmpty) return;

    late final HttpResponse r;
    switch (typeId) {
      case 8:
        r = await ctrl.updateFestiveImages(id, all);
        break;
      case 7:
        r = await ctrl.updateFuneraireImages(id, all);
        break;
      case 4:
        r = await ctrl.updateBureauImages(id, all);
        break;
      default:
        return;
    }
    if (!r.status) print('⚠️ PUT images (name/old): ${r.errorMsg}');
  }

  Future<Map<String, dynamic>> _buildTerrainOwnerPutPayload(int userId) async {
    final b = _baseline!;
    final p = widget.property;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final typeId = _getPropertyTypeId(_selectedCategory) ?? 9;

    final effCity = _isKinshasaSelected && _selectedCity?.cityId != null
        ? _selectedCity!.cityId!
        : (p.cityId ?? 1);
    final effCommune = _isKinshasaSelected && _selectedCommune?.communeId != null
        ? _selectedCommune!.communeId
        : p.communeId;
    final effQuartier = _isKinshasaSelected && _selectedQuartier?.quartierId != null
        ? _selectedQuartier!.quartierId
        : p.quartierId;

    final communeValNow = _isKinshasaSelected
        ? (_selectedCommune?.name ?? '').trim()
        : _communeTextController.text.trim();
    final quartierValNow = _isKinshasaSelected
        ? (_selectedQuartier?.name ?? '').trim()
        : _quartierTextController.text.trim();
    final cityValNow = _isKinshasaSelected ? 'Kinshasa' : _cityTextController.text.trim();

    final lat = _selectedLocation?.latitude ?? p.latitude ?? 0.1;
    final lng = _selectedLocation?.longitude ?? p.longitude ?? 0.1;
    final bLat = b.latitude ?? 0.1;
    final bLng = b.longitude ?? 0.1;

    final images = await _buildOwnerPutMainImagesPayload();
    final listingOpen = _listingStatusIndex != 2;

    return {
      'userId': userId,
      'title': PropertyOwnerPutDiff.str(_titleController.text, b.title),
      'description': PropertyOwnerPutDiff.str(_descriptionController.text, b.description),
      'deviseId': PropertyOwnerPutDiff.integer(_selectedDeviseId, b.selectedDeviseId),
      'price': PropertyOwnerPutDiff.dbl(price, b.baselinePrice),
      'surface': PropertyOwnerPutDiff.str(_areaController.text.trim(), b.areaText),
      'address': PropertyOwnerPutDiff.str(_addressController.text.trim(), b.address),
      'communeValue': PropertyOwnerPutDiff.str(communeValNow, b.communeValueResolved),
      'quartierValue': PropertyOwnerPutDiff.str(quartierValNow, b.quartierValueResolved),
      'cityValue': PropertyOwnerPutDiff.str(cityValNow, b.cityValueResolved),
      'countryValue': PropertyOwnerPutDiff.str('RDC', b.countryValueResolved),
      'cityId': PropertyOwnerPutDiff.integer(effCity, b.effectiveCityId),
      'postalCode': PropertyOwnerPutDiff.str(_postalCodeController.text.trim(), b.postalCode),
      'communeId': PropertyOwnerPutDiff.integer(effCommune ?? 0, b.effectiveCommuneId ?? 0),
      'quartierId': PropertyOwnerPutDiff.integer(effQuartier ?? 0, b.effectiveQuartierId ?? 0),
      'transactionType': _isForRent == b.isForRent ? '' : (_isForRent ? 'location' : 'vente'),
      'propertyTypeId': PropertyOwnerPutDiff.integer(typeId, b.propertyTypeId),
      'isAvailable': listingOpen,
      'latitude': PropertyOwnerPutDiff.dbl(lat, bLat),
      'longitude': PropertyOwnerPutDiff.dbl(lng, bLng),
      'images': images,
      'available': listingOpen,
    };
  }

  Future<Map<String, dynamic>> _buildFestiveOwnerPutPayload(int userId) async {
    final b = _baseline!;
    final p = widget.property;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final cap = int.tryParse(_capacityPeopleController.text) ?? p.capacityPeople ?? 0;
    final baseCap = int.tryParse(b.capacityPeopleText) ?? p.capacityPeople ?? 0;

    final electric = _hideEssentialServicesRow
        ? (p.electric ?? 0)
        : (int.tryParse(_selectedElectric ?? '') ?? 60);
    var water = _hideEssentialServicesRow
        ? (p.water ?? 0)
        : (int.tryParse(_selectedWater ?? '') ?? 60);
    if (!_hideEssentialServicesRow && water < 1) water = electric >= 1 ? electric : 60;

    final effCity = _isKinshasaSelected && _selectedCity?.cityId != null
        ? _selectedCity!.cityId!
        : (p.cityId ?? 1);
    final effCommune = _isKinshasaSelected && _selectedCommune?.communeId != null
        ? _selectedCommune!.communeId
        : p.communeId;
    final effQuartier = _isKinshasaSelected && _selectedQuartier?.quartierId != null
        ? _selectedQuartier!.quartierId
        : p.quartierId;

    final communeValNow = _isKinshasaSelected
        ? (_selectedCommune?.name ?? '').trim()
        : _communeTextController.text.trim();
    final quartierValNow = _isKinshasaSelected
        ? (_selectedQuartier?.name ?? '').trim()
        : _quartierTextController.text.trim();
    final cityValNow = _isKinshasaSelected ? 'Kinshasa' : _cityTextController.text.trim();

    final lat = _selectedLocation?.latitude ?? p.latitude ?? 0.1;
    final lng = _selectedLocation?.longitude ?? p.longitude ?? 0.1;
    final bLat = b.latitude ?? 0.1;
    final bLng = b.longitude ?? 0.1;

    final listingOpen = _listingStatusIndex != 2;

    return {
      'userId': userId,
      'deviseId': PropertyOwnerPutDiff.integer(_selectedDeviseId, b.selectedDeviseId),
      'title': PropertyOwnerPutDiff.str(_titleController.text, b.title),
      'description': PropertyOwnerPutDiff.str(_descriptionController.text, b.description),
      'usage': PropertyOwnerPutDiff.str(_festiveUsage.trim(), b.festiveUsage),
      'capacityPeople': PropertyOwnerPutDiff.integer(cap, baseCap),
      'electric': PropertyOwnerPutDiff.integer(electric, b.electricResolved),
      'price': PropertyOwnerPutDiff.dbl(price, b.baselinePrice),
      'address': PropertyOwnerPutDiff.str(_addressController.text.trim(), b.address),
      'transactionType': _isForRent == b.isForRent ? '' : (_isForRent ? 'location' : 'vente'),
      'propertyTypeId': PropertyOwnerPutDiff.integer(8, b.propertyTypeId),
      'communeValue': PropertyOwnerPutDiff.str(communeValNow, b.communeValueResolved),
      'quartierValue': PropertyOwnerPutDiff.str(quartierValNow, b.quartierValueResolved),
      'cityValue': PropertyOwnerPutDiff.str(cityValNow, b.cityValueResolved),
      'countryValue': PropertyOwnerPutDiff.str('RDC', b.countryValueResolved),
      'cityId': PropertyOwnerPutDiff.integer(effCity, b.effectiveCityId),
      'water': PropertyOwnerPutDiff.integer(water, b.waterResolved),
      'postalCode': PropertyOwnerPutDiff.str(_postalCodeController.text.trim(), b.postalCode),
      'communeId': PropertyOwnerPutDiff.integer(effCommune ?? 0, b.effectiveCommuneId ?? 0),
      'quartierId': PropertyOwnerPutDiff.integer(effQuartier ?? 0, b.effectiveQuartierId ?? 0),
      'latitude': PropertyOwnerPutDiff.dbl(lat, bLat),
      'longitude': PropertyOwnerPutDiff.dbl(lng, bLng),
      'isAvailable': listingOpen,
      'isDecore': _isDecore,
      'pisteDanse': _pisteDanse,
      'available': listingOpen,
      'decore': _isDecore,
    };
  }

  Future<Map<String, dynamic>> _buildFuneraireOwnerPutPayload(int userId) async {
    final b = _baseline!;
    final p = widget.property;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final cap = int.tryParse(_capacityPeopleController.text) ?? p.capacityPeople ?? 0;
    final baseCap = int.tryParse(b.capacityPeopleText) ?? p.capacityPeople ?? 0;

    final electric = _hideEssentialServicesRow
        ? (p.electric ?? 0)
        : (int.tryParse(_selectedElectric ?? '') ?? 60);
    final water = _hideEssentialServicesRow
        ? (p.water ?? 0)
        : (int.tryParse(_selectedWater ?? '') ?? 60);

    final effCity = _isKinshasaSelected && _selectedCity?.cityId != null
        ? _selectedCity!.cityId!
        : (p.cityId ?? 1);
    final effCommune = _isKinshasaSelected && _selectedCommune?.communeId != null
        ? _selectedCommune!.communeId
        : p.communeId;
    final effQuartier = _isKinshasaSelected && _selectedQuartier?.quartierId != null
        ? _selectedQuartier!.quartierId
        : p.quartierId;

    final communeValNow = _isKinshasaSelected
        ? (_selectedCommune?.name ?? '').trim()
        : _communeTextController.text.trim();
    final quartierValNow = _isKinshasaSelected
        ? (_selectedQuartier?.name ?? '').trim()
        : _quartierTextController.text.trim();
    final cityValNow = _isKinshasaSelected ? 'Kinshasa' : _cityTextController.text.trim();

    final lat = _selectedLocation?.latitude ?? p.latitude ?? 0.1;
    final lng = _selectedLocation?.longitude ?? p.longitude ?? 0.1;
    final bLat = b.latitude ?? 0.1;
    final bLng = b.longitude ?? 0.1;

    final listingOpen = _listingStatusIndex != 2;

    return {
      'userId': userId,
      'deviseId': PropertyOwnerPutDiff.integer(_selectedDeviseId, b.selectedDeviseId),
      'title': PropertyOwnerPutDiff.str(_titleController.text, b.title),
      'description': PropertyOwnerPutDiff.str(_descriptionController.text, b.description),
      'capacityPeople': PropertyOwnerPutDiff.integer(cap, baseCap),
      'price': PropertyOwnerPutDiff.dbl(price, b.baselinePrice),
      'address': PropertyOwnerPutDiff.str(_addressController.text.trim(), b.address),
      'transactionType': _isForRent == b.isForRent ? '' : (_isForRent ? 'location' : 'vente'),
      'propertyTypeId': PropertyOwnerPutDiff.integer(7, b.propertyTypeId),
      'communeValue': PropertyOwnerPutDiff.str(communeValNow, b.communeValueResolved),
      'quartierValue': PropertyOwnerPutDiff.str(quartierValNow, b.quartierValueResolved),
      'cityValue': PropertyOwnerPutDiff.str(cityValNow, b.cityValueResolved),
      'countryValue': PropertyOwnerPutDiff.str('RDC', b.countryValueResolved),
      'cityId': PropertyOwnerPutDiff.integer(effCity, b.effectiveCityId),
      'electric': PropertyOwnerPutDiff.integer(electric, b.electricResolved),
      'water': PropertyOwnerPutDiff.integer(water, b.waterResolved),
      'postalCode': PropertyOwnerPutDiff.str(_postalCodeController.text.trim(), b.postalCode),
      'communeId': PropertyOwnerPutDiff.integer(effCommune ?? 0, b.effectiveCommuneId ?? 0),
      'quartierId': PropertyOwnerPutDiff.integer(effQuartier ?? 0, b.effectiveQuartierId ?? 0),
      'latitude': PropertyOwnerPutDiff.dbl(lat, bLat),
      'longitude': PropertyOwnerPutDiff.dbl(lng, bLng),
      'isAvailable': listingOpen,
      'available': listingOpen,
    };
  }

  Future<Map<String, dynamic>> _buildBureauOwnerPutPayload(int userId) async {
    final b = _baseline!;
    final p = widget.property;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    final electric = _hideEssentialServicesRow
        ? (p.electric ?? 0)
        : (int.tryParse(_selectedElectric ?? '') ?? 60);
    final water = _hideEssentialServicesRow
        ? (p.water ?? 0)
        : (int.tryParse(_selectedWater ?? '') ?? 60);

    final effCity = _isKinshasaSelected && _selectedCity?.cityId != null
        ? _selectedCity!.cityId!
        : (p.cityId ?? 1);
    final effCommune = _isKinshasaSelected && _selectedCommune?.communeId != null
        ? _selectedCommune!.communeId
        : p.communeId;
    final effQuartier = _isKinshasaSelected && _selectedQuartier?.quartierId != null
        ? _selectedQuartier!.quartierId
        : p.quartierId;

    final communeValNow = _isKinshasaSelected
        ? (_selectedCommune?.name ?? '').trim()
        : _communeTextController.text.trim();
    final quartierValNow = _isKinshasaSelected
        ? (_selectedQuartier?.name ?? '').trim()
        : _quartierTextController.text.trim();
    final cityValNow = _isKinshasaSelected ? 'Kinshasa' : _cityTextController.text.trim();

    final lat = _selectedLocation?.latitude ?? p.latitude ?? 0.1;
    final lng = _selectedLocation?.longitude ?? p.longitude ?? 0.1;
    final bLat = b.latitude ?? 0.1;
    final bLng = b.longitude ?? 0.1;

    final listingOpen = _listingStatusIndex != 2;

    final roomMeetNow = p.roomMeet ?? 0;
    final numberPieceNow = int.tryParse(_roomsController.text) ?? p.numberPiece ?? 0;
    final baseNumberPiece = int.tryParse(b.roomsText) ?? p.numberPiece ?? 0;

    return {
      'userId': userId,
      'deviseId': PropertyOwnerPutDiff.integer(_selectedDeviseId, b.selectedDeviseId),
      'title': PropertyOwnerPutDiff.str(_titleController.text, b.title),
      'description': PropertyOwnerPutDiff.str(_descriptionController.text, b.description),
      'price': PropertyOwnerPutDiff.dbl(price, b.baselinePrice),
      'transactionType': _isForRent == b.isForRent ? '' : (_isForRent ? 'location' : 'vente'),
      'propertyTypeId': PropertyOwnerPutDiff.integer(4, b.propertyTypeId),
      'roomMeet': PropertyOwnerPutDiff.integer(roomMeetNow, b.roomMeet),
      'electric': PropertyOwnerPutDiff.integer(electric, b.electricResolved),
      'water': PropertyOwnerPutDiff.integer(water, b.waterResolved),
      'numberPiece': PropertyOwnerPutDiff.integer(numberPieceNow, baseNumberPiece),
      'isEquip': p.isEquip ?? false,
      'postalCode': PropertyOwnerPutDiff.str(_postalCodeController.text.trim(), b.postalCode),
      'communeId': PropertyOwnerPutDiff.integer(effCommune ?? 0, b.effectiveCommuneId ?? 0),
      'isAvailable': listingOpen,
      'quartierId': PropertyOwnerPutDiff.integer(effQuartier ?? 0, b.effectiveQuartierId ?? 0),
      'communeValue': PropertyOwnerPutDiff.str(communeValNow, b.communeValueResolved),
      'quartierValue': PropertyOwnerPutDiff.str(quartierValNow, b.quartierValueResolved),
      'cityValue': PropertyOwnerPutDiff.str(cityValNow, b.cityValueResolved),
      'countryValue': PropertyOwnerPutDiff.str('RDC', b.countryValueResolved),
      'cityId': PropertyOwnerPutDiff.integer(effCity, b.effectiveCityId),
      'latitude': PropertyOwnerPutDiff.dbl(lat, bLat),
      'longitude': PropertyOwnerPutDiff.dbl(lng, bLng),
      'address': PropertyOwnerPutDiff.str(_addressController.text.trim(), b.address),
      'available': listingOpen,
    };
  }

  /// Messages API adoucis pour l’utilisateur (pas de détails techniques).
  String _friendlyEditMessage(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Les modifications n’ont pas pu être enregistrées. Réessayez.';
    }
    final lower = raw.toLowerCase();
    if (lower.contains('internal server') ||
        lower.contains('socketexception') ||
        lower.contains('timeout') ||
        lower.contains('failed host lookup')) {
      return 'Connexion instable ou service momentanément indisponible. Patientez un peu puis réessayez.';
    }
    return raw;
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) {
      SnackbarForCasa.error(
        context,
        'Complétez les champs obligatoires indiqués avant d’enregistrer.',
      );
       return;
    }

    final subscriptionOk =
        await SubscriptionHelper.ensurePremiumForSubmit(context: context);
    if (!subscriptionOk || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final authCtrl = context.read<AuthentificationCtrl>();
      final uId = authCtrl.user.userId ?? 0;
      
      print("🛠️ DEBUG UPDATE - uId: $uId, propertyId: ${widget.property.propertyId}");

      if (uId == 0 || widget.property.propertyId == null) {
        SnackbarForCasa.error(
          context,
          'Nous ne parvenons pas à identifier votre compte ou l’annonce. Reconnectez-vous puis réessayez.',
        );
        setState(() => _isLoading = false);
        return;
      }

      if (_baseline == null) _captureEditBaseline();

      final ctrl = Provider.of<PropertyController>(context, listen: false);
      final typeId =
          _getPropertyTypeId(_selectedCategory) ?? widget.property.propertyTypeId ?? 2;

      late final HttpResponse res;
      if (_isFestiveEditType) {
        final body = await _buildFestiveOwnerPutPayload(uId);
        print("📤 PAYLOAD FESTIVE (owner flat): ${jsonEncode(body)}");
        res = await ctrl.updateFestiveByOwner(uId, widget.property.propertyId!, body);
      } else if (_isFuneraireEditType) {
        final body = await _buildFuneraireOwnerPutPayload(uId);
        print("📤 PAYLOAD FUNÉRAIRE (owner flat): ${jsonEncode(body)}");
        res = await ctrl.updateFuneraireByOwner(uId, widget.property.propertyId!, body);
      } else if (_isBureauEditType) {
        final propertyData = await _buildBureauOwnerPutPayload(uId);
        print("📤 PAYLOAD BUREAU (owner flat): ${jsonEncode(propertyData)}");
        res = await ctrl.updateBureauByOwner(uId, widget.property.propertyId!, propertyData);
      } else if (_isTerrainEditType) {
        final propertyData = await _buildTerrainOwnerPutPayload(uId);
        print("📤 PAYLOAD TERRAIN (owner flat): ${jsonEncode(propertyData)}");
        res = await ctrl.updateTerrainByOwner(uId, widget.property.propertyId!, propertyData);
      } else if (_isVacancesEditType) {
        final propertyData = await _prepareUpdateData();
        print("📤 PAYLOAD VACANCE: ${jsonEncode(propertyData)}");
        res = await ctrl.updateVacanceByOwner(uId, widget.property.propertyId!, propertyData);
      } else {
        // Même forme **plate** que la création standard (CreatePropertyPostPage) : le backend
        // attend `address` en String et `propertyImage` / `features` {featureId}, pas l’enveloppe imbriquée.
        final propertyData = await _prepareUpdateData();
        print("📤 PAYLOAD PROPRIÉTÉ (flat, aligné création): ${jsonEncode(propertyData)}");
        res = await ctrl.updatePropertyByOwner(
          uId,
          widget.property.propertyId!,
          propertyData,
        );
      }

      print("📥 REPONSE API: Status=${res.status}, Error=${res.errorMsg}");
      if (res.data != null) {
        print("📥 DATA REPONSE: ${jsonEncode(res.data)}");
      }

      if (res.status == true) {
        await _putOwnerImageEndpointsAfterSuccess(
          ctrl,
          widget.property.propertyId!,
          typeId,
        );
        SnackbarForCasa.success(context, 'Vos modifications ont bien été enregistrées.');
        Navigator.pop(context, true);
      } else {
        reportApiFailureToCrashlytics(
          'EditPropertyPage',
          response: res,
          reason: 'update_property',
        );
        String errorDetail = res.errorMsg ??
            'Les modifications n’ont pas pu être enregistrées. Réessayez.';
        if (res.data != null && res.data is Map) {
          final Map dataMap = res.data as Map;
          if (dataMap.containsKey('message')) {
            errorDetail = dataMap['message'].toString();
          } else if (dataMap.containsKey('error')) {
            errorDetail = dataMap['error'].toString();
          } else if (dataMap.containsKey('errors')) {
            errorDetail = dataMap['errors'].toString();
          }
        }

        print("❌ DETAIL ERREUR: $errorDetail");
        SnackbarForCasa.error(context, _friendlyEditMessage(errorDetail));
      }
    } catch (e, stackTrace) {
      reportApiFailureToCrashlytics(
        'EditPropertyPage',
        error: e,
        stackTrace: stackTrace,
        reason: 'update_property_exception',
      );
      print("❌ CRITICAL ERROR DURING UPDATE: $e");
      print("🔍 STACKTRACE: $stackTrace");
      SnackbarForCasa.error(
        context,
        'L’enregistrement a été interrompu. Vérifiez la connexion et réessayez.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Suppression de _showErrorDialog car on utilise SnackBarHelper désormais


  Future<Map<String, dynamic>> _prepareUpdateData() async {
    final GetStorage storage = GetStorage();
    final dynamic profile = storage.read(StockageKeys.profileKey);
    final authCtrl = context.read<AuthentificationCtrl>();
    final userId = authCtrl.user.userId;

    // Flattened payload as requested by the API
    final Map<String, dynamic> payload = {
      "title": _titleController.text.trim(),
      "description": _descriptionController.text.trim(),
      "price": double.tryParse(_priceController.text) ?? 0.0,
      "deviseId": _selectedDeviseId,
      "surface": double.tryParse(_areaController.text) ?? 0.1,
      "rooms": int.tryParse(_roomsController.text) ?? 1,
      "bedrooms": int.tryParse(_bedroomsController.text) ?? 1,
      "kitchen": int.tryParse(_kitchensController.text) ?? 1,
      "livingRoom": int.tryParse(_livingRoomsController.text) ?? 1,
      "bathroom": int.tryParse(_bathroomsController.text) ?? 1,
      "floor": int.tryParse(_floorController.text) ?? 1,
      "address": _addressController.text.trim(),
      "guarantee": _guaranteeController.text.trim().isNotEmpty ? _guaranteeController.text.trim() : "0",
      "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : _communeTextController.text.trim(),
      "quartierValue": _isKinshasaSelected ? (_selectedQuartier?.name ?? "") : _quartierTextController.text.trim(),
      "quartier": _isKinshasaSelected ? (_selectedQuartier?.name ?? "") : _quartierTextController.text.trim(),
      "cityValue": _isKinshasaSelected ? "Kinshasa" : _cityTextController.text.trim(),
      "countryValue": "RDC",
      "cityId": _isKinshasaSelected && _selectedCity?.cityId != null ? _selectedCity!.cityId! : (widget.property.cityId ?? 1),
      "communeId": _isKinshasaSelected && _selectedCommune?.communeId != null ? _selectedCommune!.communeId! : widget.property.communeId,
      "quartierId": _isKinshasaSelected && _selectedQuartier?.quartierId != null ? _selectedQuartier!.quartierId! : widget.property.quartierId,
      "electric": _hideEssentialServicesRow
          ? (widget.property.electric ?? 0)
          : (int.tryParse(_selectedElectric ?? '') ?? 60),
      "water": _hideEssentialServicesRow
          ? (widget.property.water ?? 0)
          : (int.tryParse(_selectedWater ?? '') ?? 60),
      "postalCode": _postalCodeController.text.trim(),
      "sold": _apiSoldFromListingUi,
      "isActive": _listingStatusIndex != 2,
      "isAvailable": _listingStatusIndex != 2,
      "available": _listingStatusIndex != 2,
      "transactionType": _isForRent ? "location" : "vente",
      "propertyTypeId": _getPropertyTypeId(_selectedCategory) ?? 2,
      "userId": userId,
      "latitude": _selectedLocation?.latitude ?? widget.property.latitude ?? 0.1,
      "longitude": _selectedLocation?.longitude ?? widget.property.longitude ?? 0.1,
      "features": _selectedAmenities.map((amenity) {
        return {
          "featureId": _getFeatureId(amenity),
        };
      }).toList(),
    };

    if (_isVacancesEditType) {
      payload['note'] = _vacNoteController.text.trim();
      payload['dateVacance'] = _vacDateController.text.trim();
      payload['heureVacance'] = _vacHeureController.text.trim();
      payload['priceCombo'] = _vacPriceCombo ?? 'Par Nuit';
      payload['offre'] = _vacOffreController.text.trim();
      payload['capacity'] = int.tryParse(_capacityPeopleController.text) ??
          widget.property.capacityPeople ??
          0;
    }

    // Images — seulement les catégories affichées pour ce type (évite d’écraser salon/chambre pour festive, etc.)
    for (var category in _visibleImageCategories) {
      final categoryId = category.id;
      final List<Map<String, String>> imageList = [];

      final existingUrls = _existingImageUrls[categoryId] ?? [];
      for (var url in existingUrls) {
        if (url.isNotEmpty) {
          imageList.add({"image": url});
        }
      }

      final newImages = _newImages[categoryId] ?? [];
      for (var imageFile in newImages) {
        try {
          final file = File(imageFile.path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            imageList.add({"image": base64Encode(bytes)});
          }
        } catch (e) {
          print("❌ Erreur conversion image: $e");
        }
      }

      if (imageList.isEmpty) {
        imageList.add({"image": ""});
      }

      switch (categoryId) {
        case 'propertyImage':
          payload['propertyImage'] = imageList;
          break;
        case 'propertyImageRoom':
          payload['propertyImageRoom'] = imageList;
          break;
        case 'propertyImageLivingRoom':
          payload['propertyImageLivingRoom'] = imageList;
          break;
        case 'propertyImageKitchen':
          payload['propertyImageKitchen'] = imageList;
          break;
      }
    }

    // API PropertyRequest : ces listes sont non-null côté serveur (Kotlin).
    const imageKeys = [
      'propertyImage',
      'propertyImageRoom',
      'propertyImageLivingRoom',
      'propertyImageKitchen',
    ];
    for (final key in imageKeys) {
      if (!payload.containsKey(key) || payload[key] == null) {
        payload[key] = <Map<String, dynamic>>[];
      }
    }

    return payload;
  }

  Future<void> _handleExistingImageDeletion(String categoryId, String imageUrl, int index) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Supprimer l'image ?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("Cette action est irréversible et supprimera l'image du serveur."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Annuler", style: GoogleFonts.outfit(color: _greyColor))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _errorColor, foregroundColor: Colors.white),
            child: Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final propertyId = widget.property.propertyId;
      if (propertyId == null) throw "ID Propriété manquant";

      // Préparer le payload selon le format demandé
      final Map<String, dynamic> deletePayload = {
        "propertyImage": [],
        "propertyImageRoom": [],
        "propertyImageLivingRoom": [],
        "propertyImageKitchen": [],
      };

      // Mapper categoryId Flutter aux clés API attendues
      String apiKey = "propertyImage";
      if (categoryId == 'propertyImageRoom') apiKey = "propertyImageRoom";
      else if (categoryId == 'propertyImageLivingRoom') apiKey = "propertyImageLivingRoom";
      else if (categoryId == 'propertyImageKitchen') apiKey = "propertyImageKitchen";

      deletePayload[apiKey] = [{"image": imageUrl}];

      print("🗑️ SUPPRESSION IMAGE - URL: /api/property/image/$propertyId");
      print("📤 PAYLOAD SUPPRESSION: ${jsonEncode(deletePayload)}");

      // Appeler l'API de suppression
      // Note: l'utilisateur a demandé cet endpoint spécifique. 
      // Comme c'est une suppression avec payload, on utilise deleteData si implémenté ou postData.
      // Dans requetes.dart, deleteData prend un body optionnel.
      final tkn = GetStorage().read<String>(StockageKeys.tokenKey);
      final res = await deleteData("property/image/$propertyId", data: deletePayload, token: tkn);

      print("📥 RÉPONSE SUPPRESSION: ${res.status}");

      if (res.status) {
        setState(() {
          _existingImageUrls[categoryId]!.removeAt(index);
        });
        SnackbarForCasa.success(context, 'La photo a été retirée de l’annonce.');
      } else {
        SnackbarForCasa.error(
          context,
          _friendlyEditMessage(
            res.errorMsg ??
                'La photo n’a pas pu être supprimée côté serveur. Réessayez.',
          ),
        );
      }
    } catch (e) {
      print("❌ Erreur suppression image: $e");
      SnackbarForCasa.error(
        context,
        'La suppression de la photo n’a pas abouti. Réessayez dans un instant.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDistricts() async {
    final locationCtrl = Provider.of<LocationController>(context, listen: false);
    await locationCtrl.getAllDistricts();
    if (mounted) {
      setState(() {
        _availableDistricts = locationCtrl.getDistrictsForCity(_selectedCity?.cityId ?? 1);
      });
    }
  }

  Future<void> _loadCommunes() async {
    if (_selectedDistrict?.districtId == null) return;
    final locationCtrl = Provider.of<LocationController>(context, listen: false);
    await locationCtrl.getAllCommunes();
    if (mounted) {
      setState(() {
        _availableCommunes = locationCtrl.getCommunesForDistrict(_selectedDistrict!.districtId!);
      });
    }
  }

  Future<void> _loadQuartiers() async {
    if (_selectedCommune?.communeId == null) return;
    final locationCtrl = Provider.of<LocationController>(context, listen: false);
    await locationCtrl.getAllQuartiers();
    if (mounted) {
      setState(() {
        _availableQuartiers = locationCtrl.getQuartiersForCommune(_selectedCommune!.communeId!);
      });
    }
  }

  int? _getPropertyTypeId(String? category) {
    if (category == null) return widget.property.propertyTypeId ?? 2;
    
    final Map<String, int> typeMap = {
      'Studio': 1,
      'Apparts': 2,
      'Maisons': 3,
      'Bureau': 4,
      'Hotels': 5,
      'Vacances': 6,
      'Funérariams': 7,
      'Funéraire': 7,
      'Fête': 8,
      'Fêtes': 8,
      'Festive': 8,
      'Terrain': 9,
      'Terrains': 9,
    };

    return typeMap[category] ?? widget.property.propertyTypeId ?? 2;
  }

  int _getFeatureId(String amenity) {
    final Map<String, int> featureMap = {
      'WiFi': 1,
      'Climatisation': 2,
      'Chauffage': 3,
      'Cuisine équipée': 4,
      'Lave-linge': 5,
      'Parking': 6,
      'Ascenseur': 7,
      'Piscine': 8,
      'Jardin': 9,
      'Terrasse': 10,
      'Gym': 11,
      'Sécurité': 12,
      'Animaux acceptés': 13,
    };
    return featureMap[amenity] ?? 1;
  }
}

/// Valeurs de référence après chargement (pour champs vides si inchangé sur PUT owner).
class _EditBaseline {
  final String title;
  final String description;
  final String address;
  final String postalCode;
  final String areaText;
  final String cityValueResolved;
  final String communeValueResolved;
  final String quartierValueResolved;
  final String countryValueResolved;
  final String festiveUsage;
  final String capacityPeopleText;
  final String roomsText;
  final bool isForRent;
  final int listingStatusIndex;
  final int selectedDeviseId;
  final int propertyTypeId;
  final String? selectedElectric;
  final String? selectedWater;
  final bool isDecore;
  final bool pisteDanse;
  final double? latitude;
  final double? longitude;
  final int effectiveCityId;
  final int? effectiveCommuneId;
  final int? effectiveQuartierId;
  final int electricResolved;
  final int waterResolved;
  final List<String> mainImageUrls;
  final int roomMeet;
  final int numberPiece;
  final bool isEquip;
  final double baselinePrice;

  _EditBaseline({
    required this.title,
    required this.description,
    required this.address,
    required this.postalCode,
    required this.areaText,
    required this.cityValueResolved,
    required this.communeValueResolved,
    required this.quartierValueResolved,
    required this.countryValueResolved,
    required this.festiveUsage,
    required this.capacityPeopleText,
    required this.roomsText,
    required this.isForRent,
    required this.listingStatusIndex,
    required this.selectedDeviseId,
    required this.propertyTypeId,
    required this.selectedElectric,
    required this.selectedWater,
    required this.isDecore,
    required this.pisteDanse,
    required this.latitude,
    required this.longitude,
    required this.effectiveCityId,
    required this.effectiveCommuneId,
    required this.effectiveQuartierId,
    required this.electricResolved,
    required this.waterResolved,
    required this.mainImageUrls,
    required this.roomMeet,
    required this.numberPiece,
    required this.isEquip,
    required this.baselinePrice,
  });
}

class ImageCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  ImageCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

