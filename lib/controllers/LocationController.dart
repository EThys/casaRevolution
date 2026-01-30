import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/CityModel.dart';
import '../models/CommuneModel.dart';
import '../models/DistrictModel.dart';
import '../models/QuartierModel.dart';
import '../utils/database/LocationDatabaseHelper.dart';
import '../utils/endpoints.dart';
import '../utils/requetes.dart';

class LocationController extends ChangeNotifier {
  final LocationDatabaseHelper _db = LocationDatabaseHelper.instance;

  bool _loading = false;
  List<CityModel> _cities = [];
  List<CommuneModel> _communes = [];
  List<DistrictModel> _districts = [];
  List<QuartierModel> _quartiers = [];

  // Getters
  bool get loading => _loading;
  List<CityModel> get cities => _cities;
  List<CommuneModel> get communes => _communes;
  List<DistrictModel> get districts => _districts;
  List<QuartierModel> get quartiers => _quartiers;

  // Singleton pattern
  static final LocationController _instance = LocationController._internal();
  factory LocationController() => _instance;
  LocationController._internal();

  // ==================== CITIES ====================
  Future<List<CityModel>> getAllCities({bool forceRefresh = false}) async {
    if (_cities.isNotEmpty && !forceRefresh) {
      return _cities;
    }

    _loading = true;
    notifyListeners();

    try {
      var response = await getData(Endpoints.cities);
      print("RÉPONSE API VILLES: ${response}");

      if (response != null) {
        List<CityModel> cities = _parseCityResponse(response);

        if (cities.isNotEmpty) {
          _saveCitiesToLocal(cities);
          _cities = cities;
        }

        _loading = false;
        notifyListeners();
        return cities;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur réseau pour les villes: $e");
      }
    }

    final cachedCities = await _db.getAllCities();
    _cities = cachedCities;
    _loading = false;
    notifyListeners();
    return cachedCities;
  }

  List<CityModel> _parseCityResponse(dynamic response) {
    try {
      if (response is List) {
        return response.map<CityModel>((e) => CityModel.fromJson(e)).toList();
      } else if (response is Map<String, dynamic>) {
        if (response.containsKey('cities') && response['cities'] is List) {
          return (response['cities'] as List)
              .map<CityModel>((e) => CityModel.fromJson(e))
              .toList();
        } else if (response.containsKey('data') && response['data'] is List) {
          return (response['data'] as List)
              .map<CityModel>((e) => CityModel.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du parsing des villes: $e");
      }
    }
    return [];
  }

  void _saveCitiesToLocal(List<CityModel> cities) async {
    for (var city in cities) {
      await _db.insertOrUpdateCity(city);
    }
  }

  // ==================== DISTRICTS ====================
  Future<List<DistrictModel>> getAllDistricts({bool forceRefresh = false}) async {
    if (_districts.isNotEmpty && !forceRefresh) {
      return _districts;
    }

    _loading = true;
    notifyListeners();

    try {
      var response = await getData(Endpoints.districts);
      print("RÉPONSE API DISTRICTS: ${response}");

      if (response != null) {
        List<DistrictModel> districts = _parseDistrictResponse(response);

        if (districts.isNotEmpty) {
          _saveDistrictsToLocal(districts);
          _districts = districts;
        }

        _loading = false;
        notifyListeners();
        return districts;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur réseau pour les districts: $e");
      }
    }

    final cachedDistricts = await _db.getAllDistricts();
    _districts = cachedDistricts;
    _loading = false;
    notifyListeners();
    return cachedDistricts;
  }

  List<DistrictModel> _parseDistrictResponse(dynamic response) {
    try {
      if (response is List) {
        return response.map<DistrictModel>((e) => DistrictModel.fromJson(e)).toList();
      } else if (response is Map<String, dynamic>) {
        if (response.containsKey('districts') && response['districts'] is List) {
          return (response['districts'] as List)
              .map<DistrictModel>((e) => DistrictModel.fromJson(e))
              .toList();
        } else if (response.containsKey('data') && response['data'] is List) {
          return (response['data'] as List)
              .map<DistrictModel>((e) => DistrictModel.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du parsing des districts: $e");
      }
    }
    return [];
  }

  void _saveDistrictsToLocal(List<DistrictModel> districts) async {
    for (var district in districts) {
      await _db.insertOrUpdateDistrict(district);
    }
  }

  // ==================== COMMUNES & QUARTIERS ====================
  Future<List<CommuneModel>> getAllCommunes({bool forceRefresh = false}) async {
    if (_communes.isNotEmpty && !forceRefresh) {
      return _communes;
    }

    _loading = true;
    notifyListeners();

    try {
      var response = await getData(Endpoints.communes);
      print("RÉPONSE API COMMUNES: ${response}");

      if (response != null) {
        // Extraire les communes et les quartiers
        List<CommuneModel> communes = _parseCommuneResponse(response);
        List<QuartierModel> quartiers = _extractQuartiersFromCommunes(response);

        if (communes.isNotEmpty) {
          _saveCommunesToLocal(communes);
          _communes = communes;
        }

        if (quartiers.isNotEmpty) {
          _saveQuartiersToLocal(quartiers);
          _quartiers = quartiers;
        }

        _loading = false;
        notifyListeners();
        return communes;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur réseau pour les communes: $e");
      }
    }

    final cachedCommunes = await _db.getAllCommunes();
    _communes = cachedCommunes;

    // Charger aussi les quartiers depuis le cache
    final cachedQuartiers = await _db.getAllQuartiers();
    _quartiers = cachedQuartiers;

    _loading = false;
    notifyListeners();
    return cachedCommunes;
  }

  List<CommuneModel> _parseCommuneResponse(dynamic response) {
    try {
      if (response is List) {
        return response.map<CommuneModel>((e) => CommuneModel.fromJson(e)).toList();
      } else if (response is Map<String, dynamic>) {
        if (response.containsKey('communes') && response['communes'] is List) {
          return (response['communes'] as List)
              .map<CommuneModel>((e) => CommuneModel.fromJson(e))
              .toList();
        } else if (response.containsKey('data') && response['data'] is List) {
          return (response['data'] as List)
              .map<CommuneModel>((e) => CommuneModel.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du parsing des communes: $e");
      }
    }
    return [];
  }

  List<CommuneModel> getCommunesForCity(int cityId) {
    try {
      print("🔍 Recherche des communes pour la ville ID: $cityId");

      final communesForCity = _communes.where((commune) {
        return commune.district?.city?.cityId == cityId;
      }).toList();

      print("✅ ${communesForCity.length} communes trouvées pour la ville $cityId");

      return communesForCity;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Erreur pour récupérer les communes de la ville $cityId: $e");
      }
      return [];
    }
  }

  List<QuartierModel> _extractQuartiersFromCommunes(dynamic response) {
    List<QuartierModel> allQuartiers = [];

    try {
      if (response is Map<String, dynamic>) {
        if (response.containsKey('communes') && response['communes'] is List) {
          for (var commune in response['communes']) {
            if (commune['quartiers'] is List) {
              for (var quartier in commune['quartiers']) {
                // Ajouter l'ID de la commune au quartier
                quartier['communeId'] = commune['communeId'];
                allQuartiers.add(QuartierModel.fromJson(quartier));
              }
            }
          }
        }
      } else if (response is List) {
        for (var commune in response) {
          if (commune['quartiers'] is List) {
            for (var quartier in commune['quartiers']) {
              quartier['communeId'] = commune['communeId'];
              allQuartiers.add(QuartierModel.fromJson(quartier));
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de l'extraction des quartiers: $e");
      }
    }

    print("🎯 ${allQuartiers.length} quartiers extraits des communes");
    return allQuartiers;
  }

  void _saveCommunesToLocal(List<CommuneModel> communes) async {
    for (var commune in communes) {
      await _db.insertOrUpdateCommune(commune);
    }
  }

  void _saveQuartiersToLocal(List<QuartierModel> quartiers) async {
    for (var quartier in quartiers) {
      await _db.insertOrUpdateQuartier(quartier);
    }
  }

  // ==================== QUARTIERS SPÉCIFIQUE ====================
  Future<List<QuartierModel>> getAllQuartiers({bool forceRefresh = false}) async {
    if (_quartiers.isNotEmpty && !forceRefresh) {
      return _quartiers;
    }

    // Si les quartiers ne sont pas encore chargés, charger les communes d'abord
    if (_quartiers.isEmpty) {
      await getAllCommunes(forceRefresh: forceRefresh);
    }

    return _quartiers;
  }

  // Spécial pour Kinshasa (charge les quartiers depuis /quartiers si nécessaire)
  Future<List<QuartierModel>> getKinshasaQuartiers({bool forceRefresh = false}) async {
    // 1. D'abord vérifier le cache local
    if (!forceRefresh) {
        final localQuartiers = await _db.getAllQuartiers();
        if (localQuartiers.isNotEmpty) {
            print("✅ ${localQuartiers.length} quartiers chargés depuis le cache local");
            // Filtrer pour s'assurer qu'ils appartiennent à Kinshasa (si on avait l'info ville, mais ici on assume que la table contient ceux de Kin principalement ou on retourne tout pour filtrage UI)
            // L'API /quartiers renvoie une liste plate, souvent pour la ville principale.
            _quartiers = localQuartiers; // Mise à jour de la liste principale en mémoire
            notifyListeners();
            return localQuartiers;
        }
    }

    try {
        final response = await getData('quartiers');
        if (response != null && response is Map && response.containsKey('quartiers')) {
            final List<dynamic> list = response['quartiers'];
            List<QuartierModel> fetchedQuartiers = list.map((e) => QuartierModel.fromJson(e)).toList();
            
            if (fetchedQuartiers.isNotEmpty) {
                // Sauvegarde en local
                await _db.clearQuartiers(); // On remplace pour éviter les doublons/conflits si la source change
                await _db.batchInsertQuartiers(fetchedQuartiers);
                
                print("✅ ${fetchedQuartiers.length} quartiers chargés depuis l'API et mis en cache");
                _quartiers = fetchedQuartiers;
                notifyListeners();
                return fetchedQuartiers;
            }
        }
    } catch (e) {
        print("Erreur chargement quartiers Kinshasa: $e");
    }
    
    return [];
  }

  // ==================== FILTRES COTÉ CLIENT ====================

  // Récupérer les districts d'une ville spécifique
  List<DistrictModel> getDistrictsForCity(int cityId) {
    try {
      return _districts.where((district) => district.city?.cityId == cityId).toList();
    } catch (e) {
      if (kDebugMode) {
        print("Erreur pour récupérer les districts de la ville $cityId: $e");
      }
      return [];
    }
  }

  // Récupérer les communes d'un district spécifique
  List<CommuneModel> getCommunesForDistrict(int districtId) {
    try {
      return _communes.where((commune) => commune.district?.districtId == districtId).toList();
    } catch (e) {
      if (kDebugMode) {
        print("Erreur pour récupérer les communes du district $districtId: $e");
      }
      return [];
    }
  }

  // Récupérer les quartiers d'une commune spécifique
  List<QuartierModel> getQuartiersForCommune(int communeId) {
    try {
      return _quartiers.where((quartier) => quartier.communeId == communeId).toList();
    } catch (e) {
      if (kDebugMode) {
        print("Erreur pour récupérer les quartiers de la commune $communeId: $e");
      }
      return [];
    }
  }

  // Récupérer les quartiers d'un district spécifique
  List<QuartierModel> getQuartiersForDistrict(int districtId) {
    try {
      // Récupérer toutes les communes du district
      final districtCommunes = getCommunesForDistrict(districtId);

      // Récupérer tous les quartiers de ces communes
      List<QuartierModel> allQuartiers = [];
      for (var commune in districtCommunes) {
        final communeQuartiers = getQuartiersForCommune(commune.communeId!);
        allQuartiers.addAll(communeQuartiers);
      }

      return allQuartiers;
    } catch (e) {
      if (kDebugMode) {
        print("Erreur pour récupérer les quartiers du district $districtId: $e");
      }
      return [];
    }
  }

  // Récupérer les quartiers d'une ville spécifique
  List<QuartierModel> getQuartiersForCity(int cityId) {
    try {
      // Récupérer tous les districts de la ville
      final cityDistricts = getDistrictsForCity(cityId);

      // Récupérer tous les quartiers de ces districts
      List<QuartierModel> allQuartiers = [];
      for (var district in cityDistricts) {
        final districtQuartiers = getQuartiersForDistrict(district.districtId!);
        allQuartiers.addAll(districtQuartiers);
      }

      return allQuartiers;
    } catch (e) {
      if (kDebugMode) {
        print("Erreur pour récupérer les quartiers de la ville $cityId: $e");
      }
      return [];
    }
  }

  // Recherche de quartiers par nom (avec filtre optionnel par commune)
  List<QuartierModel> searchQuartiers(String query, {int? communeId}) {
    try {
      List<QuartierModel> quartiersToSearch = communeId != null
          ? getQuartiersForCommune(communeId)
          : _quartiers;

      if (query.isEmpty) {
        return quartiersToSearch;
      }

      return quartiersToSearch
          .where((quartier) =>
      quartier.name?.toLowerCase().contains(query.toLowerCase()) ?? false)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de la recherche des quartiers: $e");
      }
      return [];
    }
  }

  // ==================== MÉTHODES DE RECHERCHE PAR ID ====================
  CityModel? getCityById(int id) {
    try {
      return _cities.firstWhere((city) => city.cityId == id);
    } catch (e) {
      return null;
    }
  }

  CommuneModel? getCommuneById(int id) {
    try {
      return _communes.firstWhere((commune) => commune.communeId == id);
    } catch (e) {
      return null;
    }
  }

  DistrictModel? getDistrictById(int id) {
    try {
      return _districts.firstWhere((district) => district.districtId == id);
    } catch (e) {
      return null;
    }
  }

  QuartierModel? getQuartierById(int id) {
    try {
      return _quartiers.firstWhere((quartier) => quartier.quartierId == id);
    } catch (e) {
      return null;
    }
  }

  // Récupérer la hiérarchie complète d'un quartier
  Map<String, dynamic>? getQuartierHierarchy(int quartierId) {
    try {
      final quartier = getQuartierById(quartierId);
      if (quartier == null) return null;

      final commune = getCommuneById(quartier.communeId!);
      if (commune == null) return null;

      final district = getDistrictById(commune.district!.districtId!);
      if (district == null) return null;

      final city = getCityById(district.city!.cityId!);
      if (city == null) return null;

      return {
        'quartier': quartier,
        'commune': commune,
        'district': district,
        'city': city,
      };
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de la récupération de la hiérarchie: $e");
      }
      return null;
    }
  }

  // ==================== CHARGEMENT DES DONNÉES ====================
  Future<void> loadAllData() async {
    _loading = true;
    notifyListeners();

    try {
      await Future.wait([
        getAllCities(),
        getAllDistricts(),
        getAllCommunes(), // Cette méthode charge aussi les quartiers
      ]);
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du chargement de toutes les données: $e");
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Chargement progressif des données
  Future<void> loadDataProgressively() async {
    _loading = true;
    notifyListeners();

    try {
      await getAllCities();
      await getAllDistricts();
      await getAllCommunes(); // Charge les communes et les quartiers
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du chargement progressif: $e");
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Vérifier si toutes les données sont chargées
  bool get isDataLoaded {
    return _cities.isNotEmpty &&
        _districts.isNotEmpty &&
        _communes.isNotEmpty &&
        _quartiers.isNotEmpty;
  }

  // Obtenir le statut de chargement
  Map<String, bool> get loadingStatus {
    return {
      'cities': _cities.isNotEmpty,
      'districts': _districts.isNotEmpty,
      'communes': _communes.isNotEmpty,
      'quartiers': _quartiers.isNotEmpty,
    };
  }

  // ==================== NETTOYAGE ====================
  void clearData() {
    _cities.clear();
    _communes.clear();
    _districts.clear();
    _quartiers.clear();
    notifyListeners();
  }

  // Nettoyer le cache
  Future<void> clearCache() async {
    await _db.clearAllData();
    clearData();
  }

  // ==================== STATISTIQUES ====================
  Map<String, int> get statistics {
    return {
      'cities': _cities.length,
      'districts': _districts.length,
      'communes': _communes.length,
      'quartiers': _quartiers.length,
    };
  }

  // Obtenir les communes avec leurs quartiers
  Map<CommuneModel, List<QuartierModel>> get communesWithQuartiers {
    Map<CommuneModel, List<QuartierModel>> result = {};

    for (var commune in _communes) {
      final quartiers = getQuartiersForCommune(commune.communeId!);
      result[commune] = quartiers;
    }

    return result;
  }
}

// Extension pour des méthodes utilitaires
extension LocationUtils on LocationController {
  // Valider si une localisation est complète
  bool isLocationComplete({
    required int? cityId,
    required int? districtId,
    required int? communeId,
    required int? quartierId,
  }) {
    return cityId != null && districtId != null && communeId != null;
  }

  // Obtenir le nom complet d'une localisation
  String getFullLocationName({
    required int? cityId,
    required int? districtId,
    required int? communeId,
    required int? quartierId,
  }) {
    final city = cityId != null ? getCityById(cityId)?.name : null;
    final district = districtId != null ? getDistrictById(districtId)?.name : null;
    final commune = communeId != null ? getCommuneById(communeId)?.name : null;
    final quartier = quartierId != null ? getQuartierById(quartierId)?.name : null;

    List<String> parts = [];
    if (quartier != null) parts.add(quartier);
    if (commune != null) parts.add(commune);
    if (district != null) parts.add(district);
    if (city != null) parts.add(city);

    return parts.join(', ');
  }
}

void main() {
  var test = LocationController();
  test.getAllCities();
}