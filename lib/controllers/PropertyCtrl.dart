import 'dart:async';
import 'dart:convert';
import 'package:casa/utils/database/DatabaseHelper.dart';
import 'package:casa/utils/database/PropertyDatabaseHelper.dart';
import 'package:casa/utils/TerrainDatabaseHelper.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart';
import '../models/PropertyModel.dart'
    show PropertyModel, HotelRoomStructure, propertyListingAllowedFromJsonLayers;
import '../models/TerrainModel.dart';
import '../models/PropertyTypeModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/Constantes.dart';
import '../utils/requetes.dart' show getData, postData, patchData, deleteData, putData, HttpResponse;
import '../models/DeviseModel.dart';
import '../models/PropertyImageModel.dart';
import '../models/PropertyFeatureModel.dart';
import '../utils/cache/HotelImageCache.dart';
import '../utils/property_snapshot_merge.dart';
import '../utils/listing_fields_parse.dart';

class PropertyController with ChangeNotifier {
  PropertyController({this.stockage});

  GetStorage? stockage;
  bool loading = false;
  bool syncing = false;
  List<PropertyModel> properties = [];
  List<PropertyModel> similarProperties = [];
  PropertyModel? currentProperty;
  
  // Property Types and Features
  List<Map<String, dynamic>> propertyTypes = [];
  List<Map<String, dynamic>> propertyFeatures = [];
  bool loadingTypes = false;
  bool loadingFeatures = false;

  // Catégories Spécialisées
  List<PropertyModel> bureaux = [];
  List<PropertyModel> festives = [];
  List<PropertyModel> funeraires = [];
  List<PropertyModel> vacances = [];
  List<PropertyModel> hotels = [];
  List<Map<String, dynamic>> terrains = [];       // données brutes (pour usage interne)
  List<PropertyModel> terrainProperties = [];     // terrains convertis en PropertyModel
  bool loadingSpecial = false;
  bool isFiltered = false; // Mode filtrage/recherche actif
  int currentPage = 0;
  bool hasMoreData = true;

  /// Exclut les annonces retirées (`is_available` == false côté API).
  List<PropertyModel> _listedOnly(List<PropertyModel> list) =>
      list.where((p) => p.listingAllowed).toList();

  /// Toutes les propriétés combinées (standard + bureaux + festives + funéraires + terrains).
  /// En mode filtré, on retourne uniquement la liste 'properties' qui contient les résultats unifiés.
  List<PropertyModel> get allProperties {
    // IMPORTANT: même en mode filtré, certains écrans (AllPropertiesPage / listes unifiées)
    // attendent un pool global. `properties` peut contenir un sous-ensemble filtré,
    // mais on garde aussi les catégories dédiées pour éviter de "perdre" terrains/hôtels/vacances.
    return [
      ..._listedOnly(properties),
      ..._listedOnly(bureaux),
      ..._listedOnly(festives),
      ..._listedOnly(funeraires),
      ..._listedOnly(vacances),
      ..._listedOnly(terrainProperties),
      ..._listedOnly(hotels),
    ];
  }

  static bool? _parseBoolLoose(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return null;
  }

  /// Complète [sold] quand l’API envoie le flag dans une enveloppe (`funeraire`, `property`, etc.).
  void _mergeSoldFromRaw(PropertyModel p, dynamic raw) {
    if (raw is! Map) return;
    final inferred =
        ListingFieldsParse.soldFromListingRaw(Map<String, dynamic>.from(raw));
    p.sold = ListingFieldsParse.mergeSold(p.sold, inferred) ?? p.sold;
  }

  Map<String, dynamic> _ownerPutBody(Map<String, dynamic> body) =>
      ListingFieldsParse.deepOmitNull(body) as Map<String, dynamic>;

  /// Convertit un Map terrain (format API/DB) en PropertyModel pour l'affichage uniforme
  PropertyModel _terrainToPropertyModel(Map<String, dynamic> t) {
    final terrainData = t['terrain'] as Map<String, dynamic>? ?? t;
    final address    = t['address']  as Map<String, dynamic>? ?? {};
    final devise     = t['devise']   as Map<String, dynamic>? ?? {};
    final typeProperty = t['typeProperty'] as Map<String, dynamic>? ?? {};
    final imagesList = (t['images'] as List<dynamic>? ?? [])
        .map((img) => img is Map ? (img['path'] as String?) ?? '' : img.toString())
        .where((s) => s.isNotEmpty)
        .toList();

    final surfaceRaw = terrainData['surface'];
    double? surface;
    if (surfaceRaw is num) {
      surface = surfaceRaw.toDouble();
    } else if (surfaceRaw is String) {
      final s = surfaceRaw.trim();
      // API terrains: surface peut venir en "20×25" / "20x25" (dimensions). On convertit en m².
      final normalized = s.replaceAll(' ', '').toLowerCase();
      final parts = normalized.split(RegExp(r'[x×]'));
      if (parts.length == 2) {
        final a = double.tryParse(parts[0].replaceAll(',', '.'));
        final b = double.tryParse(parts[1].replaceAll(',', '.'));
        if (a != null && b != null) surface = a * b;
      }
      surface ??= double.tryParse(s.replaceAll(',', '.'));
    }

    // Ne pas passer `false` quand l’API omet les champs (sinon badge « Non disponible » à tort).
    bool? listingAvail;
    if (terrainData['available'] == false ||
        terrainData['isAvailable'] == false ||
        terrainData['is_available'] == false) {
      listingAvail = false;
    } else if (terrainData['available'] == true ||
        terrainData['isAvailable'] == true ||
        terrainData['is_available'] == true) {
      listingAvail = true;
    }

    final isActive = _parseBoolLoose(terrainData['isActive']) ??
        _parseBoolLoose(terrainData['is_active']) ??
        true;
    final td = Map<String, dynamic>.from(terrainData);
    final root = Map<String, dynamic>.from(t);
    final sold = ListingFieldsParse.soldFromMaps([td, root]);
    final availFromJson = ListingFieldsParse.availableFromMaps([td, root]);

    return PropertyModel(
      propertyId:      terrainData['id'] as int?,
      title:           terrainData['title'] as String?,
      description:     terrainData['description'] as String?,
      postBy:          t['postBy'] as String?,
      image:           t['image'] as String?,
      price:           (terrainData['price'] as num?)?.toDouble(),
      surface:         surface,
      transactionType: terrainData['transactionType'] as String?,
      sold:            sold,
      isActive:        isActive,
      available:       availFromJson ?? listingAvail,
      listingAllowed:  propertyListingAllowedFromJsonLayers(terrainData, t, t),
      cityValue:       address['cityValue'] as String?,
      communeValue:    address['communeValue'] as String?,
      address:         address['address'] as String?,
      deviseId:        (devise['id'] as num?)?.toInt(),
      propertyTypeId:  (typeProperty['propertyTypeId'] as num?)?.toInt() ?? 9,
      propertyType:    PropertyTypeModel(
        propertyTypeId: (typeProperty['propertyTypeId'] as num?)?.toInt() ?? 9,
        name: typeProperty['name'] as String? ?? 'Terrain',
      ),
      propertyImage: imagesList
          .map<PropertyImageModel>((path) => PropertyImageModel(path: path))
          .toList(),
    );
  }

  // Devises
  List<DeviseModel> devisesList = [];

  Future<List<DeviseModel>> fetchDevises() async {
    try {
      final localData = stockage?.read(StockageKeys.devisesKey);
      if (localData != null && localData is Map && localData['devises'] != null) {
          devisesList = (localData['devises'] as List).map((e) => DeviseModel.fromJson(e)).toList();
          notifyListeners();
      }

      String? token = stockage?.read(StockageKeys.tokenKey);
      // Endpoints.devises = "v1/public/devises" → getData construit https://.../api/v1/public/devises
      var response = await getData(Endpoints.devises, token: token);
      if (response != null && response is Map && response['devises'] != null) {
          devisesList = (response['devises'] as List).map((e) => DeviseModel.fromJson(e)).toList();
          stockage?.write(StockageKeys.devisesKey, response);
          notifyListeners();
      }
      return devisesList;
    } catch (e) {
      print("Error fetching devises: $e");
      return devisesList;
    }
  }

  Future<void> syncProperties() async {
    syncing = true;
    notifyListeners();

    try {
      final url = "${Endpoints.properties}";
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic>) {
        dynamic propertiesData;

        if (response.containsKey('properties')) {
          propertiesData = response['properties'];
        } else if (response.containsKey('data')) {
          propertiesData = response['data'];
        } else {
          propertiesData = response;
        }

        if (propertiesData is Map && propertiesData.containsKey('content')) {
          propertiesData = propertiesData['content'];
        }

        if (propertiesData is List) {
          List<PropertyModel> onlineProperties = propertiesData
              .where((e) => e != null)
              .map<PropertyModel>((e) {
            try {
              final p = PropertyModel.fromJson(e);
              _mergeSoldFromRaw(p, e);
              return p;
            } catch (e) {
              print("Erreur lors du parsing d'une propriété: $e");
              return PropertyModel();
            }
          })
              .where((property) => property.propertyId != null)
              .toList();

          await _syncWithLocalDatabase(onlineProperties);

          // Remplacer les propriétés standard uniquement
          // Les catégories spéciales (bureaux, festives, funeraires) restent dans leurs listes dédiées
          properties = onlineProperties;

          final total = onlineProperties.length + bureaux.length + festives.length + funeraires.length + terrains.length;
          print("✅ syncProperties terminé: ${onlineProperties.length} standard + ${bureaux.length} bureaux + ${festives.length} festives + ${funeraires.length} funéraires + ${terrains.length} terrains = $total total");
        } else {
          print("Aucune donnée de propriété valide trouvée");
          await _loadFromCache();
        }
      } else {
        print("Réponse invalide ou nulle: $response");
        await _loadFromCache();
      }
    } catch (e) {
      print("Erreur lors de la synchronisation: $e");
      await _loadFromCache();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// Sync property types with local DB (Local-first strategy)
  Future<void> fetchAndSyncPropertyTypes() async {
    loadingTypes = true;
    notifyListeners();

    final db = DatabaseHelper.instance;

    try {
      // 1. Load from Local DB first
      final localTypes = await db.getAllPropertyTypes();
      if (localTypes.isNotEmpty) {
        propertyTypes = List<Map<String, dynamic>>.from(localTypes);
        print("✅ ${propertyTypes.length} catégories chargées depuis le SQL local");
        notifyListeners();
      }

      // 2. Fetch from Online API
      final url = Endpoints.propertyTypesList;
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic> && response['data'] != null) {
        final List<dynamic> onlineData = response['data'];
        final List<Map<String, dynamic>> onlineTypes = onlineData.map((e) => Map<String, dynamic>.from(e)).toList();

        // 3. Compare and Update if needed
        bool hasChanges = await _detectTypeChanges(propertyTypes, onlineTypes);

        if (hasChanges || localTypes.isEmpty) {
          print("🔄 Changements de catégories détectés ou local vide, mise à jour SQL...");
          await db.clearPropertyTypes();
          await db.insertPropertyTypes(onlineTypes);
          propertyTypes = onlineTypes;
          print("✅ SQL Catégories synchronisé avec l'API (${onlineTypes.length} types)");
        } else {
          print("✅ Pas de changement de catégories détecté en ligne");
        }
      }
    } catch (e) {
      print("⚠️ Erreur lors de la sync des types de propriété: $e");
      // Fallback: Si erreur (ex: timeout), on s'assure que les types locaux sont dispos
      if (propertyTypes.isEmpty) {
         final localTypes = await db.getAllPropertyTypes();
         if (localTypes.isNotEmpty) {
            propertyTypes = List<Map<String, dynamic>>.from(localTypes);
            print("📦 Fallback: Utilisation des types locaux suite à une erreur réseau");
         }
      }
    } finally {
      loadingTypes = false;
      notifyListeners();
    }
  }

  /// Charge toutes les catégories spéciales avec une stratégie "Local First" pour un affichage instantané
  Future<void> syncAllSpecialCategories() async {
    // 1. Charger d'abord tout depuis le SQL local pour un affichage instantané
    await _loadSpecialFromCache();
    
    // Les catégories spéciales restent dans leurs listes dédiées (bureaux, festives, funeraires)
    // Si on a des données locales, on affiche tout de suite (pas de loader bloquant)
    if (bureaux.isNotEmpty || festives.isNotEmpty || funeraires.isNotEmpty) {
       notifyListeners();
    } else {
       // Sinon on montre le loader
       loadingSpecial = true;
       notifyListeners();
    }

    try {
      await Future.wait([
        _syncSpecialCategory(Endpoints.propertyBureaux, DatabaseHelper.tableBureaux, (list) => bureaux = list),
        _syncSpecialCategory(Endpoints.propertyFestives, DatabaseHelper.tableFestives, (list) => festives = list),
        _syncSpecialCategory(Endpoints.propertyFuneraires, DatabaseHelper.tableFuneraires, (list) => funeraires = list),
        _syncSpecialCategory(Endpoints.propertyVacances, DatabaseHelper.tableVacances, (list) => vacances = list),
        _syncSpecialCategory(Endpoints.propertyHotelsPublic, DatabaseHelper.tableHotels, (list) => hotels = list),
        _syncTerrainCategory(),
      ]);
      print("🎯 Synchronisation des catégories spéciales terminée");
    } catch (e) {
      print("⚠️ Erreur lors de la sync globale des catégories spéciales: $e");
    } finally {
      loadingSpecial = false;
      notifyListeners();
    }
  }

  Future<void> _loadSpecialFromCache() async {
    final db = DatabaseHelper.instance;
    bureaux = await db.getFromCategory(DatabaseHelper.tableBureaux);
    festives = await db.getFromCategory(DatabaseHelper.tableFestives);
    funeraires = await db.getFromCategory(DatabaseHelper.tableFuneraires);
    vacances = await db.getFromCategory(DatabaseHelper.tableVacances);
    hotels = await db.getFromCategory(DatabaseHelper.tableHotels);
    
    // Load terrains from TerrainDatabaseHelper
    await _loadTerrainsFromCache();
    // print("📦 Local: ${bureaux.length} bureaux, ${festives.length} fêtes, ${funeraires.length} funéraires, ${terrains.length} terrains");
  }

  Future<void> _syncSpecialCategory(String endpoint, String tableName, Function(List<PropertyModel>) updateList) async {
    try {
      final response = await getData(endpoint);
      if (response != null && response is Map<String, dynamic>) {
        dynamic rawData;
        if (response.containsKey('bureaux')) rawData = response['bureaux'];
        else if (response.containsKey('festives')) rawData = response['festives'];
        else if (response.containsKey('funeraires')) rawData = response['funeraires'];
        else if (response.containsKey('vacances')) rawData = response['vacances'];
        else if (response.containsKey('hotels')) rawData = response['hotels'];
        else rawData = response['data'];

        print("📡 [$tableName] Response keys: ${response.keys}");
        if (rawData != null && rawData is List) {
          print("📦 [$tableName] Raw items found: ${rawData.length}");
          final List<PropertyModel> onlineList = [];
          for (var e in rawData) {
            try {
              final p = PropertyModel.fromJson(e);
              _mergeSoldFromRaw(p, e);

              if (tableName == DatabaseHelper.tableBureaux) {
                 p.propertyTypeId = 4;
                 p.propertyType = PropertyTypeModel(propertyTypeId: 4, name: 'Bureau');
              } else if (tableName == DatabaseHelper.tableFestives) {
                 p.propertyTypeId = 8;
                 p.propertyType = PropertyTypeModel(propertyTypeId: 8, name: 'Salle de fête');
              } else if (tableName == DatabaseHelper.tableFuneraires) {
                 p.propertyTypeId = 7;
                 p.propertyType = PropertyTypeModel(propertyTypeId: 7, name: 'Funéraire');
              } else if (tableName == DatabaseHelper.tableVacances) {
                 p.propertyTypeId = 10; // Assigning 10 for Vacance if not already defined
                 p.propertyType = PropertyTypeModel(propertyTypeId: 10, name: 'Vacance');
              } else if (tableName == DatabaseHelper.tableHotels) {
                 p.propertyTypeId = 5;
                 p.propertyType = PropertyTypeModel(propertyTypeId: 5, name: 'Hôtel');
              }
              
              if (p.propertyId != null) {
                onlineList.add(p);
              }
            } catch (err) {
              print("⚠️ Error parsing item in $tableName: $err");
            }
          }

          // SMART SYNC LOGIC
          final db = DatabaseHelper.instance;
          final localList = await db.getFromCategory(tableName);
          
          bool hasChanges = false;
          
          // 1. Check counts
          if (localList.length != onlineList.length) {
            hasChanges = true;
            print("🔄 [$tableName] Count mismatch (Local: ${localList.length}, Online: ${onlineList.length}) -> Sync required");
          } else {
            // 2. Check IDs and Content
            final localIds = localList.map((p) => p.propertyId).toSet();
            final onlineIds = onlineList.map((p) => p.propertyId).toSet();
            
            if (localIds.difference(onlineIds).isNotEmpty || onlineIds.difference(localIds).isNotEmpty) {
               hasChanges = true;
               print("🔄 [$tableName] ID mismatch -> Sync required");
            } else {
               // Deep comparison only if IDs match
               for (var onlineItem in onlineList) {
                  final localItem = localList.firstWhere((l) => l.propertyId == onlineItem.propertyId);
                  if (_hasPropertyChanged(localItem, onlineItem)) {
                     hasChanges = true;
                     print("🔄 [$tableName] Item ${onlineItem.propertyId} changed -> Sync required");
                     break;
                  }
               }
            }
          }

          if (hasChanges) {
             print("🚀 [$tableName] Updating local database with fresh data...");
             await db.clearCategory(tableName);
             for (var p in onlineList) {
               await db.insertOrUpdateInCategory(tableName, p);
             }
             updateList(onlineList);
          } else {
             print("✅ [$tableName] Local data is up-to-date. Using local.");
             updateList(localList); // Ensure memory uses the (verified valid) local list
          }
        } else {
             print("⚠️ [$tableName] Raw data is null or not a list");
        }
      }
    } catch (e) {
      print("⚠️ Erreur sync $endpoint: $e");
    }
  }


  void _mergeIntoMainProperties(List<PropertyModel> specialistList) {
    for (var p in specialistList) {
      if (!properties.any((existing) => existing.propertyId == p.propertyId)) {
        properties.add(p);
      }
    }
  }

  /// Load terrains from local cache and convert to PropertyModel
  Future<void> _loadTerrainsFromCache() async {
    try {
      final db = TerrainDatabaseHelper.instance;
      final cachedTerrains = await db.getAllTerrains();
      terrains = cachedTerrains;
      terrainProperties = cachedTerrains.map(_terrainToPropertyModel).toList();
      print("📦 [PropertyCtrl] ${terrains.length} terrains chargés depuis le cache local");
    } catch (e) {
      print("⚠️ [PropertyCtrl] Erreur lors du chargement des terrains depuis le cache: $e");
      terrains = [];
      terrainProperties = [];
    }
  }

  /// Sync terrains with API and local database
  Future<void> _syncTerrainCategory() async {
    try {
      final response = await getData(Endpoints.propertyTerrains);
      if (response != null && response is Map<String, dynamic>) {
        dynamic rawData = response['terrain'];
        // Tolérance: certaines versions API renvoient `data` ou `terrains`.
        rawData ??= response['terrains'];
        rawData ??= response['data'];
        if (rawData != null && rawData is List) {
          final List<Map<String, dynamic>> terrainList = rawData
              .where((e) => e is Map)
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          // Store in local database
          final db = TerrainDatabaseHelper.instance;
          await db.insertTerrains(terrainList);

          // Update in-memory lists
          terrains = terrainList;
          terrainProperties = terrainList.map(_terrainToPropertyModel).toList();

          print("✅ [PropertyCtrl] ${terrains.length} terrains synchronisés depuis l'API");
        } else {
          print("⚠️ [PropertyCtrl] Aucune donnée terrain dans la réponse API");
        }
      } else {
        print("⚠️ [PropertyCtrl] Réponse API terrain invalide");
      }
    } catch (e) {
      print("⚠️ [PropertyCtrl] Erreur sync terrains: $e");
      // En cas d'erreur, on garde les données du cache
    }
  }

  /// Détail terrain à jour (sold / disponible) pour [TerrainDetailPage].
  Future<TerrainModel?> fetchTerrainById(int terrainId) async {
    try {
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      final response = await getData('${Endpoints.propertyTerrains}/$terrainId', token: tkn);
      if (response is! Map<String, dynamic>) return null;
      if (response['terrain'] is Map<String, dynamic>) {
        return TerrainModel.fromJson(response);
      }
      return TerrainModel.fromJson({'terrain': response});
    } catch (e) {
      print('⚠️ [PropertyCtrl] fetchTerrainById: $e');
      return null;
    }
  }

  Future<bool> _detectTypeChanges(List<Map<String, dynamic>> local, List<Map<String, dynamic>> online) async {
    if (local.length != online.length) return true;
    for (int i = 0; i < online.length; i++) {
      final o = online[i];
      final exists = local.any((l) => l['propertyTypeId'] == o['propertyTypeId'] && l['name'] == o['name']);
      if (!exists) return true;
    }
    return false;
  }

  Future<void> _syncWithLocalDatabase(List<PropertyModel> onlineProperties) async {
    final db = DatabaseHelper.instance;
    final localProperties = await db.getAllProperties();
    final onlineIds = onlineProperties.map((p) => p.propertyId).toSet();
    final localIds = localProperties.map((p) => p.propertyId).toSet();
    final deletedIds = localIds.difference(onlineIds);
    for (final id in deletedIds) {
      if (id != null) await db.deleteProperty(id);
    }
    for (var property in onlineProperties) {
      await db.insertOrUpdateProperty(property);
    }
    print("Synchronisation terminée: ${onlineProperties.length} propriétés en ligne, ${deletedIds.length} supprimées localement");
  }

  Future<void> refreshProperties({bool forceSync = false}) async {
    syncing = true;
    notifyListeners();

    try {
      final url = "${Endpoints.properties}";
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic>) {
        dynamic propertiesData;
        if (response.containsKey('properties')) propertiesData = response['properties'];
        else if (response.containsKey('data')) propertiesData = response['data'];
        else propertiesData = response;

        if (propertiesData is Map && propertiesData.containsKey('content')) {
          propertiesData = propertiesData['content'];
        }

        if (propertiesData is List) {
           List<PropertyModel> onlineProperties = propertiesData
              .where((e) => e != null)
              .map<PropertyModel>((e) {
            try {
              final p = PropertyModel.fromJson(e);
              _mergeSoldFromRaw(p, e);
              return p;
            } catch (e) {
              return PropertyModel();
            }
          })
              .where((property) => property.propertyId != null)
              .toList();

          await _syncWithLocalDatabase(onlineProperties);
          properties = onlineProperties;
        } else {
          print("⚠Réponse properties vide ou invalide");
          if (!forceSync) await _loadFromCache();
        }
      } else {
         if (!forceSync) await _loadFromCache();
      }
    } catch (e) {
      print("Erreur during refresh: $e");
      if (properties.isEmpty) await _loadFromCache();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  // Synchronisation intelligente basée sur le contenu
  Future<void> _smartSyncByContent(List<PropertyModel> onlineProperties, {bool forceSync = false}) async {
    final db = DatabaseHelper.instance;
    final localProperties = await db.getAllProperties();

    // Calculer les hash pour détecter les changements
    final bool hasChanges = await _detectChanges(localProperties, onlineProperties);

    if (forceSync || hasChanges) {
      print("🔄 Changements détectés, synchronisation...");
      await _performSmartSync(localProperties, onlineProperties);

      // Loguer l'événement
     // await _logSyncEvent(onlineProperties.length, localProperties.length, true);
    } else {
      print("Aucun changement détecté, utilisation du cache");
      properties = localProperties;

      // Petit délai pour une meilleure UX même sans changement
      await Future.delayed(Duration(milliseconds: 500));

      //await _logSyncEvent(onlineProperties.length, localProperties.length, false);
    }
  }

  // Détection des changements basée sur le contenu
  Future<bool> _detectChanges(List<PropertyModel> local, List<PropertyModel> online) async {
    // 1. Vérification rapide du nombre d'éléments
    if (local.length != online.length) {
      print("Différence de nombre: local=${local.length}, online=${online.length}");
      return true;
    }

    // 2. Vérification des IDs
    final localIds = local.map((p) => p.propertyId).toSet();
    final onlineIds = online.map((p) => p.propertyId).toSet();

    final missingInLocal = onlineIds.difference(localIds);
    final missingInOnline = localIds.difference(onlineIds);

    if (missingInLocal.isNotEmpty || missingInOnline.isNotEmpty) {
      print("Différence d'IDs: +${missingInLocal.length}, -${missingInOnline.length}");
      return true;
    }

    // 3. Vérification détaillée du contenu pour chaque propriété
    for (var onlineProp in online) {
      final localProp = local.firstWhere(
            (p) => p.propertyId == onlineProp.propertyId,
        orElse: () => PropertyModel(),
      );

      if (localProp.propertyId == null) continue;

      // Comparaison des champs critiques
      if (_hasPropertyChanged(localProp, onlineProp)) {
        print("Propriété ${onlineProp.propertyId} a changé");
        return true;
      }
    }

    return false;
  }

  // Comparaison détaillée des propriétés
  bool _hasPropertyChanged(PropertyModel local, PropertyModel online) {
    // Liste des champs critiques à comparer
    return
          local.title != online.title ||
          local.price != online.price ||
          local.surface != online.surface ||
          local.rooms != online.rooms ||
          local.bedrooms != online.bedrooms ||
          local.bathroom != online.bathroom ||
          local.address != online.address ||
          local.sold != online.sold ||
          local.transactionType != online.transactionType ||
          _hasImagesChanged(local, online);
  }

  // Vérification des changements d'images
  bool _hasImagesChanged(PropertyModel local, PropertyModel online) {
    final localImages = local.propertyImage?.length ?? 0;
    final onlineImages = online.propertyImage?.length ?? 0;

    if (localImages != onlineImages) return true;

    // Comparaison basique des URLs des premières images
    if (localImages > 0 && onlineImages > 0) {
      final localFirstImage = local.propertyImage!.first.path ?? '';
      final onlineFirstImage = online.propertyImage!.first.path ?? '';
      return localFirstImage != onlineFirstImage;
    }

    return false;
  }

  // Synchronisation intelligente
  Future<void> _performSmartSync(List<PropertyModel> local, List<PropertyModel> online) async {
    final db = DatabaseHelper.instance;

    // Identifier les propriétés à supprimer (présentes en local mais pas en ligne)
    final localIds = local.map((p) => p.propertyId).toSet();
    final onlineIds = online.map((p) => p.propertyId).toSet();
    final toDelete = localIds.difference(onlineIds);

    // Supprimer les propriétés absentes en ligne
    // Supprimer les propriétés absentes en ligne
    for (final id in toDelete) {
      if (id != null) {
        await db.deleteProperty(id);
        print("🗑️ Propriété $id supprimée");
      }
    }

    // Mettre à jour/insérer les propriétés
    int updatedCount = 0;
    int insertedCount = 0;

    for (var onlineProp in online) {
      final existingProp = local.firstWhere(
            (p) => p.propertyId == onlineProp.propertyId,
        orElse: () => PropertyModel(),
      );

      if (existingProp.propertyId != null) {
        // Vérifier si la propriété a vraiment changé avant de mettre à jour
        if (_hasPropertyChanged(existingProp, onlineProp)) {
          await db.insertOrUpdateProperty(onlineProp);
          updatedCount++;
        }
      } else {
        // Nouvelle propriété
        await db.insertOrUpdateProperty(onlineProp);
        insertedCount++;
      }
    }

    // Mettre à jour la liste en mémoire
    properties = await db.getAllProperties();

    print("Sync terminée: +$insertedCount nouveau, $updatedCount modifié, ${toDelete.length} supprimé");
  }

  // Méthode pour forcer une synchronisation complète
  Future<void> forceFullSync() async {
    await refreshProperties(forceSync: true);
  }

  void _logSyncEvent(int onlineCount, int localCount, bool hadChanges) {
    print("Sync - En ligne: $onlineCount, Local: $localCount, Changements: $hadChanges");
  }

  void _showErrorNotification(String message) {
    // Cette méthode sera utilisée par l'UI pour afficher les erreurs
    print("$message");
  }





  Future<List<PropertyModel>> getAllProperty() async {
    loading = true;
    notifyListeners();

    try {
      // 1. Chargement local rapide → affichage immédiat
      await _loadFromCache();
      // Charger aussi les spéciales depuis le cache local (dans leurs listes dédiées)
      await _loadSpecialFromCache();

      loading = false;
      notifyListeners();
      print("Cache initial: ${properties.length} standard + ${bureaux.length} bureaux + ${festives.length} festives + ${funeraires.length} funéraires + ${terrains.length} terrains");

      // 2. Sync online en arrière-plan
      // syncProperties() re-fusionnera automatiquement les spéciales après l'écrasement
      syncProperties().catchError((e) {
        print("Erreur de synchronisation en arrière-plan: $e");
      });

      // 3. Sync des catégories spéciales en arrière-plan (pour les nouvelles données online)
      syncAllSpecialCategories();

      return properties;
    } catch (e) {
      print("Erreur lors du chargement: $e");
      await _loadFromCache();
      loading = false;
      notifyListeners();
      return properties;
    }
  }

  // Méthode pour charger depuis le cache seulement
  Future<void> _loadFromCache() async {
    final db = DatabaseHelper.instance;
    final cachedProperties = await db.getAllProperties();
    properties = cachedProperties;
    print("Chargement depuis le cache: ${properties.length} propriétés");
  }

  // Méthode pour forcer une synchronisation manuelle
  Future<void> forceSync() async {
    await syncProperties();
  }

  // Méthode pour vider le cache local
  Future<void> clearLocalCache() async {
    final db = DatabaseHelper.instance;
    await db.clearProperties();
    properties.clear();
    notifyListeners();
  }

  /// Recherche un [PropertyModel] déjà présent en mémoire ou en SQLite (toutes catégories).
  Future<PropertyModel?> findCachedPropertySnapshot(int propertyId, {int? typeId}) async {
    bool typeMatches(PropertyModel p) {
      if (typeId == null) return true;
      final tid = p.propertyTypeId;
      if (tid == null) return true;
      return tid == typeId;
    }

    PropertyModel? firstWithId(List<PropertyModel> list, {bool strictType = true}) {
      for (final p in list) {
        if (p.propertyId == propertyId && (!strictType || typeMatches(p))) {
          return p;
        }
      }
      return null;
    }

    final pools = <List<PropertyModel>>[
      properties,
      bureaux,
      festives,
      funeraires,
      vacances,
      hotels,
      terrainProperties,
    ];
    for (final pool in pools) {
      final hit = firstWithId(pool, strictType: true);
      if (hit != null) return hit;
    }
    for (final pool in pools) {
      final hit = firstWithId(pool, strictType: false);
      if (hit != null) return hit;
    }

    final db = DatabaseHelper.instance;
    final main = await db.getPropertyById(propertyId);
    if (main != null) return main;

    const categoryTables = [
      DatabaseHelper.tableBureaux,
      DatabaseHelper.tableFestives,
      DatabaseHelper.tableFuneraires,
      DatabaseHelper.tableVacances,
      DatabaseHelper.tableHotels,
    ];
    for (final table in categoryTables) {
      final rows = await db.getFromCategory(table);
      final hit = firstWithId(rows, strictType: true) ?? firstWithId(rows, strictType: false);
      if (hit != null) return hit;
    }
    return null;
  }

  Future<PropertyModel> enrichPropertySnapshot(PropertyModel partial) async {
    final id = partial.propertyId;
    if (id == null) return partial;
    final snap = await findCachedPropertySnapshot(id, typeId: partial.propertyTypeId);
    return PropertySnapshotMerge.mergeFillMissing(partial, snap);
  }

  Future<PropertyModel> _persistHotelSnapshot(PropertyModel property) async {
    final db = DatabaseHelper.instance;
    final hydrated = await db.hydrateHotelFromRoomCache(property);
    await db.insertOrUpdateProperty(hydrated);
    await db.insertOrUpdateInCategory(DatabaseHelper.tableHotels, hydrated);
    await db.persistHotelRoomRows(hydrated);
    unawaited(HotelImageCache.instance.prefetchUrls(HotelImageCache.urlsOf(hydrated)));
    return hydrated;
  }

  /// Hôtels : pas de `GET /property/{id}` — catalogue [Endpoints.propertyHotelsPublic] puis détail chambre optionnel.
  Future<PropertyModel?> _fetchHotelFromPublicCatalog(int hotelId,
      {PropertyModel? mergeWith}) async {
    try {
      // Cache local: si on a déjà un hôtel enrichi (structures + images chambres), on peut éviter
      // de re-télécharger les détails de chaque chambre (très lent sur réseau mobile).
      PropertyModel? cachedHotel;
      try {
        cachedHotel = await DatabaseHelper.instance
            .getCategoryPropertyById(DatabaseHelper.tableHotels, hotelId);
      } catch (_) {
        cachedHotel = null;
      }

      final response = await getData(Endpoints.propertyHotelsPublic);
      if (response == null || response is! Map<String, dynamic>) return null;
      final data = response['data'];
      if (data is! List) return null;

      Map<String, dynamic>? match;
      for (final item in data) {
        if (item is! Map) continue;
        final hotel = item['hotel'];
        if (hotel is! Map) continue;
        final id = hotel['id'];
        final same = id == hotelId ||
            id.toString() == hotelId.toString();
        if (same) {
          match = Map<String, dynamic>.from(item);
          break;
        }
      }
      if (match == null) return null;

      PropertyModel property = PropertyModel.fromJson(match);
      if (mergeWith != null &&
          mergeWith.propertyId != null &&
          property.propertyId == mergeWith.propertyId) {
        property = PropertySnapshotMerge.mergeFillMissing(mergeWith, property);
      }
      if (cachedHotel != null &&
          cachedHotel.propertyId != null &&
          cachedHotel.propertyId == property.propertyId) {
        // Préférer les champs riches déjà en cache (structures/images) + garder les champs récents du catalogue.
        property = PropertySnapshotMerge.mergeFillMissing(property, cachedHotel);
      }

      final structures = property.hotelStructure;
      if (structures != null && structures.isNotEmpty) {
        // Map cache chambreId -> structure enrichie (si dispo).
        final Map<int, HotelRoomStructure> cachedById = {};
        final cachedStructs = cachedHotel?.hotelStructure ?? const <HotelRoomStructure>[];
        for (final s in cachedStructs) {
          final id = s.chambre?.id;
          if (id == null) continue;
          cachedById[id] = s;
        }

        // 1) Construire une version "instantanée" en utilisant cache chambreId quand dispo.
        final List<HotelRoomStructure> immediate = [];
        final List<int> toFetch = [];
        for (final struct in structures) {
          final cid = struct.chambre?.id;
          if (cid == null) {
            immediate.add(struct);
            continue;
          }
          HotelRoomStructure? roomCache;
          try {
            roomCache = await DatabaseHelper.instance.getHotelRoomById(cid);
          } catch (_) {
            roomCache = null;
          }
          final cachedStruct = cachedById[cid];
          final cachedImgs = (roomCache?.images?.isNotEmpty == true)
              ? (roomCache?.images ?? const <PropertyImageModel>[])
              : (cachedStruct?.images ?? const <PropertyImageModel>[]);
          final cachedHasDetailText =
              ((roomCache?.chambre?.description?.trim().isNotEmpty ?? false) ||
                  (cachedStruct?.chambre?.description?.trim().isNotEmpty ?? false));
          if (cachedImgs.isNotEmpty || cachedHasDetailText) {
            immediate.add(
              HotelRoomStructure(
                chambre: roomCache?.chambre ?? cachedStruct?.chambre ?? struct.chambre,
                images: cachedImgs.isNotEmpty ? cachedImgs : (struct.images ?? const <PropertyImageModel>[]),
              ),
            );
          } else {
            immediate.add(struct);
            toFetch.add(cid);
          }
        }
        property = property.copyWith(hotelStructure: immediate);

        // 2) Enrichissement en arrière-plan (parallèle, limité) + cache `hotel_rooms` + update hôtel.
        if (toFetch.isNotEmpty) {
          Future(() async {
            try {
              // limiter la concurrence: lots de 6
              const int chunkSize = 6;
              final Map<int, HotelRoomStructure> fetchedById = {};
              for (var i = 0; i < toFetch.length; i += chunkSize) {
                final chunk = toFetch.sublist(i, (i + chunkSize).clamp(0, toFetch.length));
                final futures = chunk.map((cid) async {
                  try {
                    final chResp = await getData("${Endpoints.propertyHotelRoomsPublic}/$cid");
                    if (chResp is Map<String, dynamic> && chResp['data'] is List) {
                      final arr = chResp['data'] as List;
                      if (arr.isNotEmpty && arr.first is Map) {
                        final enriched = HotelRoomStructure.fromJson(
                          Map<String, dynamic>.from(arr.first as Map),
                        );
                        fetchedById[cid] = enriched;
                        // cache chambreId
                        await DatabaseHelper.instance.insertOrUpdateHotelRoom(enriched);
                      }
                    }
                  } catch (_) {}
                }).toList();
                await Future.wait(futures);
              }

              if (fetchedById.isEmpty) return;

              // Fusionner avec le snapshot courant + sauvegarder l’hôtel enrichi.
              final mergedRooms = <HotelRoomStructure>[];
              for (final s in immediate) {
                final cid = s.chambre?.id;
                final fetched = (cid != null) ? fetchedById[cid] : null;
                if (fetched == null) {
                  mergedRooms.add(s);
                } else {
                  final apiImgs = fetched.images;
                  final catalogImgs = s.images;
                  final mergedImages = (apiImgs != null && apiImgs.isNotEmpty)
                      ? apiImgs
                      : (catalogImgs ?? const <PropertyImageModel>[]);
                  mergedRooms.add(
                    HotelRoomStructure(
                      chambre: fetched.chambre ?? s.chambre,
                      images: mergedImages,
                    ),
                  );
                }
              }
              final enrichedHotel = property.copyWith(hotelStructure: mergedRooms);
              await _persistHotelSnapshot(enrichedHotel);
              // notifier les listeners pour refresh UI si l’écran écoute le controller
              hotels = hotels.map((h) => h.propertyId == enrichedHotel.propertyId ? enrichedHotel : h).toList();
              notifyListeners();
            } catch (_) {}
          });
        }
      }

      final saved = await _persistHotelSnapshot(property);
      currentProperty = saved;
      return saved;
    } catch (e) {
      print('❌ _fetchHotelFromPublicCatalog: $e');
      return null;
    }
  }

  Future<PropertyModel?> getPropertyById(int propertyId,
      {int? propertyTypeId, PropertyModel? mergeWith}) async {
    loading = true;
    notifyListeners();

    try {
      var skipGenericPropertyGet = false;
      if (propertyTypeId == 5) {
        final hotel = await _fetchHotelFromPublicCatalog(propertyId,
            mergeWith: mergeWith);
        if (hotel != null) {
          loading = false;
          notifyListeners();
          return hotel;
        }
        skipGenericPropertyGet = true;
      }

      dynamic response;
      if (!skipGenericPropertyGet) {
        // Déterminer l'URL appropriée selon le type si connu
        String urlBase = Endpoints.properties;
        if (propertyTypeId != null) {
          if (propertyTypeId == 4) urlBase = Endpoints.propertyBureaux;
          else if (propertyTypeId == 5) urlBase = Endpoints.properties;
          else if (propertyTypeId == 7) urlBase = Endpoints.propertyFuneraires;
          else if (propertyTypeId == 8) urlBase = Endpoints.propertyFestives;
          else if (propertyTypeId == 9) urlBase = Endpoints.propertyTerrains;
          else if (propertyTypeId == 11) urlBase = Endpoints.propertyVacances;
        }

        final url = "$urlBase/$propertyId";
        response = await getData(url);
      } else {
        response = null;
      }

      // Si 404 sur le premier essai et qu'on n'avait pas de type, tenter les spécialisés
      if (response == null && propertyTypeId == null) {
         // Liste ordonnée des endpoints probables pour un ID donné
         final fallbacks = [
            Endpoints.propertyBureaux,
            Endpoints.propertyFestives,
            Endpoints.propertyFuneraires,
            Endpoints.propertyVacances,
            Endpoints.propertyTerrains,
            Endpoints.propertyHotelsPublic,
         ];
         for (var fb in fallbacks) {
            if (fb == Endpoints.propertyHotelsPublic) {
              final hotel = await _fetchHotelFromPublicCatalog(propertyId,
                  mergeWith: mergeWith);
              if (hotel != null) {
                loading = false;
                notifyListeners();
                return hotel;
              }
              continue;
            }
            response = await getData("$fb/$propertyId");
            if (response != null) break;
         }
      }

      if (response != null) {
        // Nouvelle structure: { properties: {...}, similaires: [...] }
        dynamic propertyJson;
        dynamic similarJson;

        if (response is Map<String, dynamic>) {
          if (response['properties'] != null) {
            propertyJson = response['properties'];
          } else if (response['data'] != null) {
            propertyJson = response['data'];
          } else if (response['bureau'] != null) {
            propertyJson = response['bureau'];
          } else if (response['festive'] != null) {
            propertyJson = response['festive'];
          } else if (response['funeraire'] != null) {
            propertyJson = response['funeraire'];
          } else if (response['hotel'] != null) {
            propertyJson = response;
          } else if (response['terrain'] != null) {
            propertyJson = response['terrain'];
          } else if (response['vacance'] != null) {
            propertyJson = response['vacance'];
          }
          
          if (response['similaires'] != null) {
            similarJson = response['similaires'];
          }
        }

        if (propertyJson != null) {
          PropertyModel property = PropertyModel.fromJson(Map<String, dynamic>.from(propertyJson));
          _mergeSoldFromRaw(property, propertyJson);
          if (response is Map<String, dynamic>) {
            _mergeSoldFromRaw(property, response);
          }
          if (mergeWith != null &&
              mergeWith.propertyId != null &&
              property.propertyId == mergeWith.propertyId) {
            property = PropertySnapshotMerge.mergeFillMissing(mergeWith, property);
          }
          currentProperty = property;

          // Similar properties
          if (similarJson is List) {
            similarProperties = similarJson
                .where((e) => e != null)
                .map<PropertyModel>((e) {
                  try {
                    final sp = PropertyModel.fromJson(Map<String, dynamic>.from(e));
                    _mergeSoldFromRaw(sp, e);
                    return sp;
                  } catch (_) {
                    return PropertyModel();
                  }
                })
                .where((p) => p.propertyId != null)
                .toList();
          } else {
            similarProperties = [];
          }

          // Mettre à jour le cache local
          final db = DatabaseHelper.instance;
          await db.insertOrUpdateProperty(property);

          loading = false;
          notifyListeners();
          return property;
        }
      }
    } catch (e) {
      print("Erreur réseau pour la propriété $propertyId : $e");
      // Si échec réseau, chercher dans le cache local
    }

    // Chercher dans le cache local
    final db = DatabaseHelper.instance;
    final cachedProperty = await db.getPropertyById(propertyId);

    if (cachedProperty != null) {
      PropertyModel out = cachedProperty;
      if (mergeWith != null &&
          mergeWith.propertyId != null &&
          cachedProperty.propertyId == mergeWith.propertyId) {
        out = PropertySnapshotMerge.mergeFillMissing(mergeWith, cachedProperty);
      }
      currentProperty = out;
      similarProperties = [];
      loading = false;
      notifyListeners();
      return out;
    }

    final hotelRow =
        await db.getCategoryPropertyById(DatabaseHelper.tableHotels, propertyId);
    if (hotelRow != null) {
      PropertyModel out = hotelRow;
      if (mergeWith != null &&
          mergeWith.propertyId != null &&
          hotelRow.propertyId == mergeWith.propertyId) {
        out = PropertySnapshotMerge.mergeFillMissing(mergeWith, hotelRow);
      }
      currentProperty = out;
      similarProperties = [];
      loading = false;
      notifyListeners();
      return out;
    }

    loading = false;
    notifyListeners();
    return null;
  }

  Future<HttpResponse> createProperty(Map<String, dynamic> propertyData) async {
    try {
      loading = true;
      notifyListeners();

      print("🚀 Envoi de la requête createProperty...");
      print("📊 Données envoyées: ${propertyData.keys.toList()}");

      final url = Endpoints.storeProperty;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await postData(url, propertyData, token: tkn);

      // Vérifier si la requête a réussi (basé sur le status)
      print("📊 Réponse reçue - Status: ${response.status}, Data: ${response.data != null ? 'présent' : 'null'}, Error: ${response.errorMsg}");
      
      if (response.status == true) {
        // Traitement de la réponse réussie
        if (response.data != null && response.data is Map) {
          // Vérifier différentes structures de réponse possibles
          dynamic propertyJson;

          if (response.data['properties'] != null) {
            propertyJson = response.data['properties'];
            print("📦 Structure 'properties' détectée");
          } else if (response.data['data'] != null) {
            propertyJson = response.data['data'];
            print("📦 Structure 'data' détectée");
          } else if (response.data['propertyId'] != null) {
            propertyJson = response.data; // La réponse EST la propriété
            print("📦 Structure directe de propriété détectée");
          } else if (response.data['message'] != null) {
            // Réponse avec seulement un message de succès
            print("✅ Réponse avec message: ${response.data['message']}");
            propertyJson = null;
          }

          if (propertyJson != null && propertyJson is Map) {
            try {
              //print("🔄 Tentative de parsing PropertyModel...");

              // Créer une copie sécurisée des données
              final safePropertyJson = Map<String, dynamic>.from(propertyJson);

              // Nettoyer les données problématiques
              safePropertyJson.removeWhere((key, value) => value == null);

              final newProperty = PropertyModel.fromJson(safePropertyJson);

              // Vérifier que la propriété a un ID valide
              if (newProperty.propertyId != null && newProperty.propertyId! > 0) {
                properties.add(newProperty);

                // Mettre à jour le cache local
                final db = DatabaseHelper.instance;
                await db.insertOrUpdateProperty(newProperty);

                notifyListeners();
                print("✅ Propriété ajoutée avec succès: ${newProperty.propertyId}");
              } else {
                print("⚠️ Propriété parsée mais ID invalide ou manquant: ${newProperty.propertyId}");
              }
            } catch (e) {
              print("❌ Erreur lors du parsing de la propriété: $e");
              print("❌ Données qui ont échoué: $propertyJson");

              // Mais on continue car l'API a répondu positivement
              // La propriété est créée côté serveur même si le parsing échoue
            }
          } else {
            print("ℹ️ Aucune donnée de propriété trouvée dans la réponse, mais requête réussie");
            if (response.data['message'] != null) {
              print("📝 Message du serveur: ${response.data['message']}");
            }
          }
        } else {
          print("⚠️ Réponse data est null ou non-Map, mais requête réussie selon le status");
        }
      } else {
        // Requête échouée
        print("❌ Requête échouée selon le status");
        if (response.errorMsg != null) {
          print("❌ Message d'erreur: ${response.errorMsg}");
        }
      }

      loading = false;
      notifyListeners();

      // RETOURNER TOUJOURS LA RÉPONSE
      return response;

    } catch (e) {
      print("❌ Erreur critique dans createProperty: $e");

      loading = false;
      notifyListeners();

      return HttpResponse(
          status: false,
          errorMsg: "Erreur lors de la création: ${e.toString()}",
          isException: true,
          data: {
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String()
          }
      );
    }
  }

  Future<HttpResponse> createBureau(Map<String, dynamic> bureauData) async {
    try {
      loading = true;
      notifyListeners();

      print("🚀 Envoi de la requête createBureau...");
      print("📊 Données envoyées: ${bureauData.keys.toList()}");

      final url = Endpoints.storeBureau;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await postData(url, bureauData, token: tkn);

      print("📊 Réponse reçue - Status: ${response.status}, Data: ${response.data != null ? 'présent' : 'null'}, Error: ${response.errorMsg}");

      if (response.status == true) {
        if (response.data != null && response.data is Map) {
           print("✅ Bureau créé avec succès");
        }
      }

      loading = false;
      notifyListeners();
      return response;

    } catch (e) {
      print("❌ Erreur critique dans createBureau: $e");
      loading = false;
      notifyListeners();
      return HttpResponse(
          status: false,
          errorMsg: "Erreur lors de la création du bureau: ${e.toString()}",
          isException: true,
          data: {'error': e.toString()}
      );
    }
  }

  /// Création hôtel (`POST` [Endpoints.propertyHotels]) — aligné dashboard `hotels/new`.
  Future<HttpResponse> createHotel(Map<String, dynamic> hotelData) async {
    try {
      loading = true;
      notifyListeners();

      print("🚀 Envoi de la requête createHotel...");
      print("📊 Données envoyées: ${hotelData.keys.toList()}");

      final url = Endpoints.propertyHotels;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await postData(url, hotelData, token: tkn);

      print("📊 Réponse createHotel - Status: ${response.status}, Error: ${response.errorMsg}");

      if (response.status == true && response.data is Map) {
        print("✅ Hôtel créé");
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      print("❌ Erreur critique dans createHotel: $e");
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors de la création de l'hôtel: ${e.toString()}",
        isException: true,
        data: {'error': e.toString()},
      );
    }
  }

  /// Création chambre (`POST` [Endpoints.propertyHotelRoom]) — aligné dashboard `hotel/hotels/[id]`.
  Future<HttpResponse> createHotelRoom(Map<String, dynamic> body) async {
    try {
      loading = true;
      notifyListeners();

      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      final response = await postData(Endpoints.propertyHotelRoom, body, token: tkn);

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors de la création de la chambre: ${e.toString()}",
        isException: true,
        data: {'error': e.toString()},
      );
    }
  }

  /// Identifiant utilisateur pour les endpoints « owner » (hôtels, etc.).
  String? _ownerUserIdFromStorage() {
    String? userId;
    final userData = stockage?.read(StockageKeys.userKey);
    final profileData = stockage?.read(StockageKeys.profileKey);
    if (userData is Map || profileData is Map) {
      if (userData is Map) {
        if (userData.containsKey('user') && userData['user'] is Map && userData['user']?['userId'] != null) {
          userId = userData['user']?['userId']?.toString();
        } else if (userData.containsKey('userId') && userData['userId'] != null) {
          userId = userData['userId']?.toString();
        }
        if ((userId == null || userId.isEmpty) && userData.containsKey('profile') && userData['profile'] is Map) {
          userId = userData['profile']?['userId']?.toString();
        }
      }
    }
    return (userId != null && userId.isNotEmpty) ? userId : null;
  }

  /// Hôtels type 5 depuis le cache utilisateur (affichage immédiat).
  Future<List<PropertyModel>> loadMyHotelsFromDatabase() async {
    final userId = _ownerUserIdFromStorage();
    if (userId == null) return [];
    try {
      return (await PropertyDatabaseHelper.instance.getMyProperties(userId))
          .where((p) => p.propertyTypeId == 5)
          .toList();
    } catch (e) {
      print('⚠️ loadMyHotelsFromDatabase: $e');
      return [];
    }
  }

  /// Récupère les hôtels sur l’API et met à jour [PropertyDatabaseHelper]. Renvoie `[]` si échec réseau / vide.
  Future<List<PropertyModel>> syncOwnerHotelsToDatabase() async {
    final userId = _ownerUserIdFromStorage();
    if (userId == null) return [];

    try {
      final fresh = await fetchHotelsByOwner();
      if (fresh.isEmpty) return [];

      final userDb = PropertyDatabaseHelper.instance;
      final cached = await loadMyHotelsFromDatabase();
      final cachedIds = cached.map((p) => p.propertyId).whereType<int>().toSet();
      final onlineIds = fresh.map((p) => p.propertyId).whereType<int>().toSet();
      for (final id in cachedIds.difference(onlineIds)) {
        await userDb.deleteProperty(id.toString());
      }
      for (final h in fresh) {
        await userDb.insertOrUpdateProperty(h, userId);
      }
      notifyListeners();
      return fresh;
    } catch (e) {
      print('⚠️ syncOwnerHotelsToDatabase: $e');
      return [];
    }
  }

  /// Cache puis API (pour appels one-shot). Préférer [loadMyHotelsFromDatabase] + [syncOwnerHotelsToDatabase] pour l’UI progressive.
  Future<List<PropertyModel>> getMyHotelsOfflineFirst() async {
    final cached = await loadMyHotelsFromDatabase();
    final fresh = await syncOwnerHotelsToDatabase();
    return fresh.isNotEmpty ? fresh : cached;
  }

  /// Hôtels du propriétaire (`GET` [Endpoints.propertyHotelsByOwner]`{userId}`).
  Future<List<PropertyModel>> fetchHotelsByOwner() async {
    final userId = _ownerUserIdFromStorage();
    if (userId == null) return [];

    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    final url = "${Endpoints.propertyHotelsByOwner}$userId";
    try {
      final response = await getData(url, token: tkn);
      if (response == null) return [];
      dynamic raw = response;
      if (response is Map) {
        raw = response['data'] ?? response['hotels'] ?? response['properties'] ?? response;
      }
      if (raw is! List) return [];
      final out = <PropertyModel>[];
      for (final e in raw) {
        if (e == null) continue;
        try {
          final m = Map<String, dynamic>.from(e as Map);
          final p = PropertyModel.fromJson(m);
          p.propertyTypeId ??= 5;
          p.propertyType ??= PropertyTypeModel(propertyTypeId: 5, name: 'Hôtel');
          if (p.propertyId != null) out.add(p);
        } catch (err) {
          print("⚠️ fetchHotelsByOwner parse: $err");
        }
      }
      return out;
    } catch (e) {
      print("❌ fetchHotelsByOwner: $e");
      return [];
    }
  }

  Future<HttpResponse> createFuneraire(Map<String, dynamic> funeraireData) async {
    try {
      loading = true;
      notifyListeners();

      print("⚰️ Envoi de la requête createFuneraire...");
      print("📊 Données envoyées: ${funeraireData.keys.toList()}");

      final url = Endpoints.storeFuneraire; 
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await postData(url, funeraireData, token: tkn);

      print("📊 Réponse reçue - Status: ${response.status}, Data: ${response.data != null ? 'présent' : 'null'}, Error: ${response.errorMsg}");

      if (response.status == true) {
         print("✅ Salle funéraire créée avec succès");
      }

      loading = false;
      notifyListeners();
      return response;

    } catch (e) {
      print("❌ Erreur critique dans createFuneraire: $e");
      loading = false;
      notifyListeners();
      return HttpResponse(
          status: false,
          errorMsg: "Erreur lors de la création de la salle funéraire: ${e.toString()}",
          isException: true,
          data: {'error': e.toString()}
      );
    }
  }

  Future<HttpResponse> createFestive(Map<String, dynamic> festiveData) async {
    try {
      loading = true;
      notifyListeners();

      print("🚀 Envoi de la requête createFestive...");
      print("📊 Données envoyées: ${festiveData.keys.toList()}");

      final url = Endpoints.storeFestive;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await postData(url, festiveData, token: tkn);

      print("📊 Réponse reçue - Status: ${response.status}, Data: ${response.data != null ? 'présent' : 'null'}, Error: ${response.errorMsg}");

      if (response.status == true) {
         print("✅ Salle festive créée avec succès");
      }

      loading = false;
      notifyListeners();
      return response;

    } catch (e) {
      print("❌ Erreur critique dans createFestive: $e");
      loading = false;
      notifyListeners();
      return HttpResponse(
          status: false,
          errorMsg: "Erreur lors de la création festive: ${e.toString()}",
          isException: true,
          data: {'error': e.toString()}
      );
    }
  }

  Future<HttpResponse> createVacance(Map<String, dynamic> vacancesData) async {
    try {
      loading = true;
      notifyListeners();

      print("🚀 Envoi de la requête createVacance...");
      print("📊 Données envoyées: ${vacancesData.keys.toList()}");

      final url = Endpoints.storeVacance;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await postData(url, vacancesData, token: tkn);

      print("📊 Réponse reçue - Status: ${response.status}, Data: ${response.data != null ? 'présent' : 'null'}, Error: ${response.errorMsg}");

      if (response.status == true) {
         print("✅ Vacance créée avec succès");
      }

      loading = false;
      notifyListeners();
      return response;

    } catch (e) {
      print("❌ Erreur critique dans createVacance: $e");
      loading = false;
      notifyListeners();
      return HttpResponse(
          status: false,
          errorMsg: "Erreur lors de la création de la vacance: ${e.toString()}",
          isException: true,
          data: {'error': e.toString()}
      );
    }
  }

  Future<HttpResponse> createTerrain(Map<String, dynamic> terrainData) async {
    try {
      loading = true;
      notifyListeners();

      print("🚀 Envoi de la requête createTerrain...");
      print("📊 Données envoyées: ${terrainData.keys.toList()}");

      final url = Endpoints.storeTerrain;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await postData(url, terrainData, token: tkn);

      print("📊 Réponse reçue - Status: ${response.status}, Data: ${response.data != null ? 'présent' : 'null'}, Error: ${response.errorMsg}");

      if (response.status == true) {
         print("✅ Terrain créé avec succès");
      }

      loading = false;
      notifyListeners();
      return response;

    } catch (e) {
      print("❌ Erreur critique dans createTerrain: $e");
      loading = false;
      notifyListeners();
      return HttpResponse(
          status: false,
          errorMsg: "Erreur lors de la création du terrain: ${e.toString()}",
          isException: true,
          data: {'error': e.toString()}
      );
    }
  }

  /// API migration: `PUT /api/v1/protected/property/*/sold/{id}` avec payload `{ "status": true/false }`.
  /// Dans l’app, on garde la convention historique: `sold=true` => indisponible ; `sold=false` => disponible.
  Future<HttpResponse> syncPropertySoldFlag(int propertyId, int propertyTypeId, {required bool sold}) async {
    try {
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      final String base;
      switch (propertyTypeId) {
        case 5:
          base = Endpoints.soldHotel;
          break;
        case 9:
          base = Endpoints.soldTerrain;
          break;
        case 4:
          base = Endpoints.soldBureau;
          break;
        case 8:
          base = Endpoints.soldFestive;
          break;
        case 7:
          base = Endpoints.soldFuneraire;
          break;
        case 6:
        case 10:
        case 11:
          base = Endpoints.soldVacance;
          break;
        default:
          base = Endpoints.soldProperty;
          break;
      }
      final url = '$base$propertyId';
      print('📌 [PropertyCtrl] syncPropertySoldFlag PUT $url sold=$sold (type=$propertyTypeId)');
      print('🌐 [PropertyCtrl] BASE: ${Constantes.BASE_URL}');
      print('🌐 [PropertyCtrl] URL complète: ${Constantes.BASE_URL}$url');
      // Backend: `status=true` signifie "indisponible" (équivalent de `sold=true` dans l’app)
      final status = sold;
      print('📤 [PropertyCtrl] Payload: {"status": $status} (derived from sold=$sold)');
      final resp = await putData(url, {'status': status}, token: tkn);

      // Certains endpoints migration renvoient un HTTP 400 mais avec un message "… succès".
      // On le traite comme succès pour ne pas bloquer l'UX.
      if (resp.status != true && resp.data is Map) {
        final msg = (resp.data['message'] ?? resp.data['detailMessage'] ?? '')
            .toString()
            .toLowerCase();
        if (msg.contains('succ') || msg.contains('success')) {
          return HttpResponse(
            status: true,
            data: resp.data,
            httpStatus: resp.httpStatus,
          );
        }
      }
      return resp;
    } catch (e) {
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  /// Chambre d'hôtel: on conserve le champ modèle `available` côté app,
  /// mais la bascule se fait via le même mécanisme `sold` côté API.
  /// - `sold=true`  → indisponible
  /// - `sold=false` → disponible
  Future<HttpResponse> syncHotelRoomSoldFlag(int chambreId, {required bool sold}) async {
    try {
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      final url = '${Endpoints.soldHotelRoom}$chambreId';
      print('📌 [PropertyCtrl] syncHotelRoomSoldFlag PUT $url sold=$sold');
      // Backend: `status=true` signifie "indisponible" (équivalent de `sold=true` dans l’app)
      final status = sold;
      print('📤 [PropertyCtrl] Payload: {"status": $status} (derived from sold=$sold)');
      final resp = await putData(url, {'status': status}, token: tkn);
      if (resp.status != true && resp.data is Map) {
        final msg = (resp.data['message'] ?? resp.data['detailMessage'] ?? '')
            .toString()
            .toLowerCase();
        if (msg.contains('succ') || msg.contains('success')) {
          return HttpResponse(
            status: true,
            data: resp.data,
            httpStatus: resp.httpStatus,
          );
        }
      }
      return resp;
    } catch (e) {
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  // Nouvelle méthode pour mettre à jour une propriété par owner
  Future<HttpResponse> updatePropertyByOwner(int userId, int propertyId, Map<String, dynamic> propertyData) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.updatePropertyOwner}$userId/$propertyId";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      print("🔄 Mise à jour propriété: $url");
      print("📤 PAYLOAD COMPLET: ${jsonEncode(propertyData)}");

      HttpResponse response = await putData(
        url,
        _ownerPutBody(propertyData),
        token: tkn,
      );

      if (response.status && response.data != null) {
        // Mettre à jour la propriété dans la liste locale
        final index = properties.indexWhere((p) => p.propertyId == propertyId);
        if (index != -1) {
          try {
            final updatedProperty = PropertyModel.fromJson(response.data);
            properties[index] = updatedProperty;
            
            // Mettre à jour le cache local
            final db = DatabaseHelper.instance;
            await db.insertOrUpdateProperty(updatedProperty);
            
            print("✅ Propriété $propertyId mise à jour avec succès");
          } catch (e) {
            print("⚠️ Erreur lors du parsing de la propriété mise à jour: $e");
          }
        }
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      print("❌ Erreur lors de la mise à jour: $e");
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors de la mise à jour: ${e.toString()}",
        isException: true,
      );
    }
  }

  /// PUT salles festives — même enveloppe que la création (`festive`, `images`, `features`).
  /// URL API : `/api/{version}/protected/property/festives/owner/{festiveId}` (sans userId dans le chemin).
  Future<HttpResponse> updateFestiveByOwner(int userId, int festiveId, Map<String, dynamic> body) async {
    try {
      loading = true;
      notifyListeners();
      final url = '${Endpoints.updateFestiveOwner}$festiveId';
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      print('🔄 Mise à jour festive: $url');
      final response = await putData(url, _ownerPutBody(body), token: tkn);
      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  /// PUT salles funéraires — `/protected/property/funeraires/owner/{funeraireId}`.
  Future<HttpResponse> updateFuneraireByOwner(int userId, int funeraireId, Map<String, dynamic> body) async {
    try {
      loading = true;
      notifyListeners();
      final url = '${Endpoints.updateFuneraireOwner}$funeraireId';
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      print('🔄 Mise à jour funéraire: $url');
      final response = await putData(url, _ownerPutBody(body), token: tkn);
      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  /// PUT bureaux — `/protected/property/bureaux/owner/{bureauId}`.
  Future<HttpResponse> updateBureauByOwner(int userId, int bureauId, Map<String, dynamic> body) async {
    try {
      loading = true;
      notifyListeners();
      final url = '${Endpoints.updateBureauOwner}$bureauId';
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      print('🔄 Mise à jour bureau: $url');
      final response = await putData(url, _ownerPutBody(body), token: tkn);
      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  /// PUT vacances — `/protected/property/vacances/owner/{vacanceId}`.
  Future<HttpResponse> updateVacanceByOwner(int userId, int vacanceId, Map<String, dynamic> body) async {
    try {
      loading = true;
      notifyListeners();
      final url = '${Endpoints.updateVacanceOwner}$vacanceId';
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      print('🔄 Mise à jour vacance: $url');
      final response = await putData(url, _ownerPutBody(body), token: tkn);
      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  /// PUT terrains — `/protected/property/terrains/owner/{terrainId}`.
  Future<HttpResponse> updateTerrainByOwner(int userId, int terrainId, Map<String, dynamic> body) async {
    try {
      loading = true;
      notifyListeners();
      final url = '${Endpoints.updateTerrainOwner}$terrainId';
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      print('🔄 Mise à jour terrain: $url');
      final response = await putData(url, _ownerPutBody(body), token: tkn);
      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  /// PUT images terrain — `/protected/property/terrains/image/{terrainId}`.
  Future<HttpResponse> updateTerrainImages(int terrainId, List<Map<String, String>> images) async {
    try {
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      final url = '${Endpoints.updateTerrainImage}$terrainId';
      print('🔄 Mise à jour images terrain: $url');
      return await putData(url, _ownerPutBody({'images': images}), token: tkn);
    } catch (e) {
      return HttpResponse(status: false, errorMsg: e.toString(), isException: true);
    }
  }

  /// PUT images salle festive — `/protected/property/festives/image/{festiveId}`.
  Future<HttpResponse> updateFestiveImages(int festiveId, List<Map<String, String>> images) async {
    try {
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      final url = '${Endpoints.updateFestiveImage}$festiveId';
      print('🔄 Mise à jour images festive: $url');
      return await putData(url, _ownerPutBody({'images': images}), token: tkn);
    } catch (e) {
      return HttpResponse(status: false, errorMsg: e.toString(), isException: true);
    }
  }

  /// PUT images funéraire — `/protected/property/funeraires/image/{funeraireId}`.
  Future<HttpResponse> updateFuneraireImages(int funeraireId, List<Map<String, String>> images) async {
    try {
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      final url = '${Endpoints.updateFuneraireImage}$funeraireId';
      print('🔄 Mise à jour images funéraire: $url');
      return await putData(url, _ownerPutBody({'images': images}), token: tkn);
    } catch (e) {
      return HttpResponse(status: false, errorMsg: e.toString(), isException: true);
    }
  }

  /// PUT images bureau — `/protected/property/bureaux/image/{bureauId}`.
  Future<HttpResponse> updateBureauImages(int bureauId, List<Map<String, String>> images) async {
    try {
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      final url = '${Endpoints.updateBureauImage}$bureauId';
      print('🔄 Mise à jour images bureau: $url');
      return await putData(url, _ownerPutBody({'images': images}), token: tkn);
    } catch (e) {
      return HttpResponse(status: false, errorMsg: e.toString(), isException: true);
    }
  }

  Future<HttpResponse> updateProperty(int id, Map<String, dynamic> propertyData) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.properties}/$id";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await patchData(url, propertyData, token: tkn);

      if (response.data != null &&
          (response.data['property'] != null || response.data['data'] != null)) {

        dynamic propertyJson = response.data['property'] ?? response.data['data'];

        if (propertyJson != null) {
          final updatedProperty = PropertyModel.fromJson(propertyJson);

          // Mettre à jour la liste en mémoire
          final index = properties.indexWhere((p) => p.propertyId == id);
          if (index != -1) {
            properties[index] = updatedProperty;
          }
          if (currentProperty?.propertyId == id) {
            currentProperty = updatedProperty;
          }

          // Mettre à jour le cache local
          final db = DatabaseHelper.instance;
          await db.insertOrUpdateProperty(updatedProperty);

          notifyListeners();
        }
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Failed to update property: $e",
        isException: true,
      );
    }
  }

  Future<HttpResponse> deleteProperty(int id) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.deleteProperty}$id";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await deleteData(url, token: tkn);

      // Vérifier le succès basé sur la structure de votre HttpResponse
      if (response.status == true) {
        // Supprimer de la liste en mémoire
        properties.removeWhere((p) => p.propertyId == id);
        if (currentProperty?.propertyId == id) {
          currentProperty = null;
        }

        // Supprimer du cache local
        final db = DatabaseHelper.instance;
        await db.deleteProperty(id);

        notifyListeners();
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Failed to delete property: $e",
        isException: true,
      );
    }
  }

  // Récupérer les propriétés de l'utilisateur connecté
  Future<List<PropertyModel>> getMyProperties() async {
    loading = true;
    
    try {
      final userData = stockage?.read(StockageKeys.userKey);
      final profileData = stockage?.read(StockageKeys.profileKey);
      String? userId;
      
      if (userData is Map || profileData is Map) {
        if (userData is Map) {
          if (userData.containsKey('user') && userData['user'] is Map && userData['user']?['userId'] != null) {
            userId = userData['user']?['userId']?.toString();
          } else if (userData.containsKey('userId') && userData['userId'] != null) {
            userId = userData['userId']?.toString();
          }
        }
        
        if (userId == null || userId.isEmpty) {
          if (userData is Map && userData.containsKey('profile') && userData['profile'] is Map) {
             userId = userData['profile']?['userId']?.toString();
          }
        }
      }
      
      if (userId == null || userId.isEmpty) {
        print("❌ Aucun user ID trouvé pour récupérer les propriétés");
        loading = false;
        notifyListeners();
        return [];
      }

      print("✅ UserId récupéré: $userId");
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      final endpoints = [
        "${Endpoints.propertiesByOwner}$userId",
        "${Endpoints.propertyBureauxByOwner}$userId",
        "${Endpoints.propertyFestivesByOwner}$userId",
        "${Endpoints.propertyFunerairesByOwner}$userId",
        "${Endpoints.propertyVacancesByOwner}$userId",
        "${Endpoints.propertyTerrainsByOwner}$userId",
        "${Endpoints.propertyHotelsByOwner}$userId",
      ];

      List<PropertyModel> allMyProperties = [];

      for (String url in endpoints) {
        try {
          print("🌐 URL de la requête: ${Constantes.BASE_URL}$url");
          var response = await getData(url, token: tkn);
          
          if (response != null) {
            dynamic propertiesData;
            if (response is Map && response.containsKey('properties')) {
              propertiesData = response['properties'];
            } else if (response is Map && response.containsKey('data')) {
              propertiesData = response['data'];
            } else {
              propertiesData = response;
            }

            if (propertiesData is List) {
              final List<PropertyModel> fetchedList = propertiesData
                  .where((e) => e != null)
                  .map<PropertyModel>((e) {
                    try {
                      final property = PropertyModel.fromJson(Map<String, dynamic>.from(e));
                      _mergeSoldFromRaw(property, e);
                      if (url.contains('bureaux')) property.propertyTypeId = 4;
                      else if (url.contains('festives')) property.propertyTypeId = 8;
                      else if (url.contains('funeraires')) property.propertyTypeId = 7;
                      else if (url.contains('/vacances/owner')) {
                        property.propertyTypeId = property.propertyTypeId == 0 ? 11 : property.propertyTypeId;
                      }                       else if (url.contains('/terrains/owner')) {
                        property.propertyTypeId = 9;
                      } else if (url.contains('hotels/owner')) {
                        property.propertyTypeId = 5;
                        property.propertyType ??= PropertyTypeModel(propertyTypeId: 5, name: 'Hôtel');
                      }
                      return property;
                    } catch (e) {
                      print("❌ Erreur parsing property in $url: $e");
                      return PropertyModel();
                    }
                  })
                  .where((p) => p.propertyId != null)
                  .toList();
              
              allMyProperties.addAll(fetchedList);
            }
          }
        } catch (e) {
          print("⚠️ Erreur lors de la récupération depuis $url: $e");
        }
      }

      if (allMyProperties.isEmpty) {
        print("⚠️ Aucune donnée trouvée en ligne, essai chargement cache local");
        await _loadFromCache();
        final myProperties = properties.where((p) => p.userId?.toString() == userId).toList();
        loading = false;
        notifyListeners();
        return myProperties;
      }

      List<PropertyModel> myProperties = allMyProperties.where((p) {
        return (p.userId?.toString() == userId) || (p.userId == 0);
      }).toList();
          
      // Sauvegarder dans le cache utilisateur (PropertyDatabaseHelper)
      try {
        final userDb = PropertyDatabaseHelper.instance;
        // Pour une sync parfaite (cas suppression), on vide le cache personnel avant d'insérer
        await userDb.clearMyProperties(userId);
        await userDb.insertOrUpdateProperties(myProperties, userId);
        print("✅ ${myProperties.length} propriétés sauvegardées dans le cache utilisateur");
      } catch (e) {
        print("⚠️ Erreur sauvegarde cache utilisateur: $e");
      }

      // Sauvegarder aussi dans DatabaseHelper (cache général)
      final db = DatabaseHelper.instance;
      final localProperties = await db.getAllProperties();
      final userLocalIds = localProperties
          .where((p) => p.userId?.toString() == userId)
          .map((p) => p.propertyId)
          .toSet();
      
      final onlineIds = myProperties.map((p) => p.propertyId).toSet();
      final toDelete = userLocalIds.difference(onlineIds);
      
      for (final id in toDelete) {
        if (id != null) await db.deleteProperty(id);
      }

      for (final p in myProperties) {
        await db.insertOrUpdateProperty(p);
      }

      loading = false;
      notifyListeners();
      return myProperties;
    } catch (e) {
      print("❌ Erreur lors de la récupération des propriétés: $e");
      
      // En cas d'erreur réseau, charger depuis le cache utilisateur
      try {
        final userData = stockage?.read(StockageKeys.userKey);
        final profileData = stockage?.read(StockageKeys.profileKey);
        String? userId;
        
        if (userData is Map || profileData is Map) {
          if (userData is Map) {
            if (userData.containsKey('user') && userData['user'] is Map && userData['user']?['userId'] != null) {
              userId = userData['user']?['userId']?.toString();
            } else if (userData.containsKey('userId') && userData['userId'] != null) {
              userId = userData['userId']?.toString();
            }
          }
        }
        
        if (userId != null && userId.isNotEmpty) {
          final userDb = PropertyDatabaseHelper.instance;
          final cachedProperties = await userDb.getMyProperties(userId);
          
          if (cachedProperties.isNotEmpty) {
            print("📦 ${cachedProperties.length} propriétés chargées depuis le cache hors ligne");
            loading = false;
            notifyListeners();
            return cachedProperties;
          }
        }
      } catch (cacheError) {
        print("❌ Erreur chargement cache: $cacheError");
      }
      
      loading = false;
      notifyListeners();
      return [];
    }
  }

  // Méthode utilitaire pour vérifier si une propriété existe en ligne
  Future<bool> isPropertyOnline(int propertyId) async {
    try {
      final url = "${Endpoints.properties}/$propertyId";
      final response = await getData(url);
      return response != null && response['data'] != null;
    } catch (e) {
      return false;
    }
  }

  // Méthode pour filtrer seulement les propriétés en ligne
  Future<List<PropertyModel>> getOnlinePropertiesOnly() async {
    await syncProperties(); // Synchroniser d'abord
    return properties; // Maintenant properties contient seulement les propriétés en ligne
  }

  Future<HttpResponse> filterProperties({
    bool? sold,
    double? minPrice,
    double? maxPrice,
    int? typeMaison,
    int? city,
    int? commune,
    int? room,
    int page = 0,
    int size = 15,
    String sortBy = 'id',
    String sortOrder = 'desc',
    bool isLoadMore = false,
  }) async {
    try {
      if (!isLoadMore) {
        loading = true;
        isFiltered = true;
        currentPage = 0;
        hasMoreData = true;
        notifyListeners();
      }
      
      // 1. Recherche locale au premier appel uniquement
      if (!isLoadMore) {
        await _filterLocalProperties(
          sold: sold,
          minPrice: minPrice,
          maxPrice: maxPrice,
          typeMaison: typeMaison,
          city: city,
          commune: commune,
          room: room,
        );
        loading = false;
        notifyListeners();
      }

      // 2. Requête réseau en arrière-plan
      final Map<String, dynamic> queryParams = {};

      if (sold != null) queryParams['sold'] = sold.toString();
      if (minPrice != null) queryParams['minPrice'] = minPrice.toString();
      if (maxPrice != null) queryParams['maxPrice'] = maxPrice.toString();
      if (typeMaison != null) queryParams['typeMaison'] = typeMaison.toString();
      if (city != null) queryParams['city'] = city.toString();
      if (commune != null) queryParams['commune'] = commune.toString();
      if (room != null) queryParams['room'] = room.toString();

      queryParams['page'] = page.toString();
      queryParams['size'] = size.toString();
      queryParams['sortBy'] = sortBy;
      queryParams['sortOrder'] = sortOrder;

      final url = "${Endpoints.propertyFilter}?${_buildQueryString(queryParams)}";

      print("🔍 URL de filtrage: $url");

      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      
      // Lancement asynchrone pour ne pas bloquer l'UI
      getData(url, token: tkn).then((response) {
        if (response.status == true && response.data != null) {
          dynamic propertiesData;

          if (response.data is Map) {
            if (response.data.containsKey('content')) {
              propertiesData = response.data['content'];
              // Vérifier s'il y a plus de pages (format Spring Pageable)
              final bool last = response.data['last'] ?? true;
              hasMoreData = !last;
            } else if (response.data.containsKey('properties')) {
              propertiesData = response.data['properties'];
            } else if (response.data.containsKey('data')) {
              propertiesData = response.data['data'];
            }
          }

          if (propertiesData is List && propertiesData.isNotEmpty) {
            List<PropertyModel> apiFiltered = propertiesData
                .where((e) => e != null)
                .map<PropertyModel>((e) {
              try {
                final p = PropertyModel.fromJson(e);
                _mergeSoldFromRaw(p, e);
                return p;
              } catch (e) {
                return PropertyModel();
              }
            })
                .where((property) => property.propertyId != null)
                .toList();

            if (isLoadMore) {
              // Éviter les doublons
              final existingIds = properties.map((p) => p.propertyId).toSet();
              final newItems = apiFiltered.where((p) => !existingIds.contains(p.propertyId)).toList();
              properties.addAll(newItems);
              currentPage++;
            } else {
              properties = apiFiltered;
            }
            print("✅ Filtrage réseau réussi: ${apiFiltered.length} propriétés trouvées. hasMore: $hasMoreData");
            notifyListeners();
          } else if (propertiesData is List && propertiesData.isEmpty) {
            hasMoreData = false;
            notifyListeners();
          }
        }
      }).catchError((e) {
         print("❌ Erreur réseau lors du filtrage: $e");
      });

      return HttpResponse(status: true, data: properties);

    } catch (e) {
      print("❌ Erreur critique dans filterProperties: $e");

      // En cas d'erreur réseau, essayer de filtrer localement
      await _filterLocalProperties(
        sold: sold,
        minPrice: minPrice,
        maxPrice: maxPrice,
        typeMaison: typeMaison,
        city: city,
        commune: commune,
        room: room,
      );

      loading = false;
      notifyListeners();

      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors du filtrage: ${e.toString()}",
        isException: true,
      );
    }
  }

  // Méthode pour filtrer les propriétés en cache local
  Future<void> _filterLocalProperties({
    bool? sold,
    double? minPrice,
    double? maxPrice,
    int? typeMaison,
    int? city,
    int? commune,
    int? room,
  }) async {
    final db = DatabaseHelper.instance;
    final standardProps = await db.getAllProperties();

    // Charger d'abord les catégories spéciales depuis le cache pour avoir un pool complet et frais
    final bureauRepo = await db.getFromCategory(DatabaseHelper.tableBureaux);
    final festiveRepo = await db.getFromCategory(DatabaseHelper.tableFestives);
    final funeraireRepo = await db.getFromCategory(DatabaseHelper.tableFuneraires);
    final vacancesRepo = await db.getFromCategory(DatabaseHelper.tableVacances);
    final hotelsRepo = await db.getFromCategory(DatabaseHelper.tableHotels);
    final terrainRepoRaw = await TerrainDatabaseHelper.instance.getAllTerrains();
    final terrainRepo = terrainRepoRaw.map(_terrainToPropertyModel).toList();

    // Pool complet : standard + toutes catégories spéciales
    final allPool = [
      ...standardProps,
      ...bureauRepo,
      ...festiveRepo,
      ...funeraireRepo,
      ...vacancesRepo,
      ...hotelsRepo,
      ...terrainRepo,
    ];

    bool _matches(PropertyModel property) {
      // Filtre sold / transactionType
      if (sold != null) {
        final tx = property.transactionType?.toLowerCase() ?? '';
        final isLocation = tx.contains('location');
        // sold=false → location, sold=true → vente
        if (sold == false && !isLocation) return false;
        if (sold == true  &&  isLocation) return false;
      }

      // Filtre prix
      if (minPrice != null && (property.price ?? 0) < minPrice) return false;
      if (maxPrice != null && (property.price ?? double.maxFinite) > maxPrice) return false;

      // Filtre type de bien
      if (typeMaison != null && property.propertyTypeId != typeMaison) return false;

      // Filtre ville (par ID ou par nom selon dispo)
      if (city != null && property.cityId != null && property.cityId != city) return false;

      // Filtre commune
      if (commune != null && property.communeId != null && property.communeId != commune) return false;

      // Filtre pièces (non applicable aux terrains)
      if (room != null && property.propertyTypeId != 9 && property.rooms != room) return false;

      return true;
    }

    // Capture tous les matches du pool complet dans 'properties' pour le mode filtré
    properties = allPool.where(_matches).toList();

    // Filtrer aussi les listes spéciales indépendamment pour les pages de catégories
    if (typeMaison == null || typeMaison == 4)
      bureaux = (await db.getFromCategory(DatabaseHelper.tableBureaux)).where(_matches).toList();
    else bureaux = [];

    if (typeMaison == null || typeMaison == 8)
      festives = (await db.getFromCategory(DatabaseHelper.tableFestives)).where(_matches).toList();
    else festives = [];

    if (typeMaison == null || typeMaison == 7)
      funeraires = (await db.getFromCategory(DatabaseHelper.tableFuneraires)).where(_matches).toList();
    else funeraires = [];

    if (typeMaison == null || typeMaison == 9) {
      final cachedTerrains = await TerrainDatabaseHelper.instance.getAllTerrains();
      terrainProperties = cachedTerrains.map(_terrainToPropertyModel).where(_matches).toList();
    } else terrainProperties = [];

    // Vacances / Hôtels (pour les pages dédiées et la cohérence du pool)
    if (typeMaison == null || typeMaison == 6 || typeMaison == 10 || typeMaison == 11) {
      vacances = (await db.getFromCategory(DatabaseHelper.tableVacances)).where(_matches).toList();
    } else {
      vacances = [];
    }
    if (typeMaison == null || typeMaison == 5) {
      hotels = (await db.getFromCategory(DatabaseHelper.tableHotels)).where(_matches).toList();
    } else {
      hotels = [];
    }

    print("🔍 Filtrage local: ${allProperties.length} résultats (${properties.length} std + ${bureaux.length} bur + ${festives.length} fes + ${funeraires.length} fun + ${terrainProperties.length} terra)");
  }

  // Méthode utilitaire pour construire la query string
  String _buildQueryString(Map<String, dynamic> params) {
    return params.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
        .join('&');
  }

  // Méthode pour réinitialiser les filtres et charger toutes les propriétés
  Future<void> resetFilters() async {
    isFiltered = false;
    await getAllProperty();
  }

  // Méthode pour rechercher par texte (titre, description, etc.)
  Future<HttpResponse> searchProperties(String searchTerm, {int page = 0, int size = 15, bool isLoadMore = false}) async {
    try {
      if (!isLoadMore) {
        loading = true;
        isFiltered = true;
        currentPage = 0;
        hasMoreData = true;
        notifyListeners();

        // 1. Recherche locale instantanée
        await _searchLocalProperties(searchTerm);
        loading = false;
        notifyListeners();
      }

      // 2. Recherche en ligne en arrière-plan
      final url = "${Endpoints.propertySearch}?query=${Uri.encodeComponent(searchTerm)}&page=${isLoadMore ? currentPage + 1 : 0}&size=$size";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      getData(url, token: tkn).then((response) {
        if (response.status == true && response.data != null) {
          dynamic propertiesData;

          if (response.data is Map) {
            if (response.data.containsKey('content')) {
              propertiesData = response.data['content'];
              final bool last = response.data['last'] ?? true;
              hasMoreData = !last;
            } else if (response.data.containsKey('properties')) {
              propertiesData = response.data['properties'];
            } else if (response.data.containsKey('data')) {
              propertiesData = response.data['data'];
            }
          }

          if (propertiesData is List && propertiesData.isNotEmpty) {
            List<PropertyModel> searchResults = propertiesData
                .where((e) => e != null)
                .map<PropertyModel>((e) {
                  try {
                    final p = PropertyModel.fromJson(e);
                    _mergeSoldFromRaw(p, e);
                    return p;
                  } catch (_) {
                    return PropertyModel();
                  }
                })
                .where((property) => property.propertyId != null)
                .toList();

            if (isLoadMore) {
              final existingIds = properties.map((p) => p.propertyId).toSet();
              final newItems = searchResults.where((p) => !existingIds.contains(p.propertyId)).toList();
              properties.addAll(newItems);
              currentPage++;
            } else {
              properties = searchResults;
            }
            print("🔍 Recherche en ligne réussie: ${searchResults.length} résultats. hasMore: $hasMoreData");
            notifyListeners();
          } else if (propertiesData is List && propertiesData.isEmpty) {
            hasMoreData = false;
            notifyListeners();
          }
        }
      }).catchError((e) {
         print("❌ Erreur réseau lors de la recherche: $e");
      });

      return HttpResponse(status: true, data: properties);

    } catch (e) {
      print("❌ Erreur lors de la recherche: $e");

      // Recherche locale en fallback
      await _searchLocalProperties(searchTerm);

      loading = false;
      notifyListeners();

      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors de la recherche: ${e.toString()}",
        isException: true,
      );
    }
  }

  // Méthode pour rechercher localement
  Future<void> _searchLocalProperties(String searchTerm) async {
    final db = DatabaseHelper.instance;
    final term = searchTerm.toLowerCase();

    bool _matchesSearch(PropertyModel property) {
      if (property.title?.toLowerCase().contains(term) == true) return true;
      if (property.description?.toLowerCase().contains(term) == true) return true;
      if (property.address?.toLowerCase().contains(term) == true) return true;
      if (property.cityValue?.toLowerCase().contains(term) == true) return true;
      if (property.communeValue?.toLowerCase().contains(term) == true) return true;
      return false;
    }

    // Charger toutes les catégories pour un pool de recherche complet
    final standardProps = await db.getAllProperties();
    final bureauRepo = await db.getFromCategory(DatabaseHelper.tableBureaux);
    final festiveRepo = await db.getFromCategory(DatabaseHelper.tableFestives);
    final funeraireRepo = await db.getFromCategory(DatabaseHelper.tableFuneraires);
    final vacancesRepo = await db.getFromCategory(DatabaseHelper.tableVacances);
    final hotelsRepo = await db.getFromCategory(DatabaseHelper.tableHotels);
    final terrainRepoRaw = await TerrainDatabaseHelper.instance.getAllTerrains();
    final terrainRepo = terrainRepoRaw.map(_terrainToPropertyModel).toList();

    // Pool complet pour la recherche unifiée
    final allPool = [
      ...standardProps,
      ...bureauRepo,
      ...festiveRepo,
      ...funeraireRepo,
      ...vacancesRepo,
      ...hotelsRepo,
      ...terrainRepo,
    ];
    properties = allPool.where(_matchesSearch).toList();

    // Mettre à jour les listes filtrées par catégorie
    bureaux = bureauRepo.where(_matchesSearch).toList();
    festives = festiveRepo.where(_matchesSearch).toList();
    funeraires = funeraireRepo.where(_matchesSearch).toList();
    vacances = vacancesRepo.where(_matchesSearch).toList();
    hotels = hotelsRepo.where(_matchesSearch).toList();
    terrainProperties = terrainRepo.where(_matchesSearch).toList();

    print("🔍 Recherche locale terminée: ${allProperties.length} résultats globaux pour '$searchTerm'");
  }



  // ========== Property Types Methods ==========
  
  /// Sync property types from API and cache locally
  Future<void> syncPropertyTypes() async {
    loadingTypes = true;
    notifyListeners();

    try {
      final url = "${Endpoints.properties}/types"; // Correct endpoint
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic>) {
        dynamic typesData;
        
        if (response.containsKey('data')) {
          typesData = response['data'];
        } else if (response.containsKey('propertyTypes')) {
          typesData = response['propertyTypes'];
        } else {
          typesData = response;
        }

        if (typesData is List) {
          final List<Map<String, dynamic>> types = typesData
              .where((e) => e != null)
              .map<Map<String, dynamic>>((e) => {
                    'propertyTypeId': e['propertyTypeId'],
                    'name': e['name'],
                    'description': e['description'],
                  })
              .toList();

          // Save to local database
          final db = DatabaseHelper.instance;
          await db.insertPropertyTypes(types);

          // Update in-memory list
          propertyTypes = types;
          
          // Store sync timestamp
          stockage?.write('property_types_last_sync', DateTime.now().millisecondsSinceEpoch);
          
          print("✅ ${types.length} types de propriété synchronisés");
        } else {
          print("⚠️ Aucune donnée de type trouvée");
          await _loadPropertyTypesFromCache();
        }
      } else {
        print("⚠️ Réponse invalide pour les types");
        await _loadPropertyTypesFromCache();
      }
    } catch (e) {
      print("❌ Erreur sync types: $e");
      await _loadPropertyTypesFromCache();
    } finally {
      loadingTypes = false;
      notifyListeners();
    }
  }

  /// Get property types (from memory, cache, or API)
  Future<List<Map<String, dynamic>>> getPropertyTypes() async {
    // If already loaded in memory, return immediately
    if (propertyTypes.isNotEmpty) {
      return propertyTypes;
    }

    // Try to load from cache
    await _loadPropertyTypesFromCache();
    
    if (propertyTypes.isNotEmpty) {
      // Check if cache is stale (older than 24 hours)
      final lastSync = stockage?.read<int>('property_types_last_sync');
      if (lastSync != null) {
        final age = DateTime.now().millisecondsSinceEpoch - lastSync;
        if (age < 86400000) { // 24 hours in milliseconds
          return propertyTypes;
        }
      }
    }

    // Cache is empty or stale, sync from API
    await syncPropertyTypes();
    return propertyTypes;
  }

  /// Load property types from local cache
  Future<void> _loadPropertyTypesFromCache() async {
    try {
      final db = DatabaseHelper.instance;
      propertyTypes = await db.getAllPropertyTypes();
      print("📦 ${propertyTypes.length} types chargés depuis le cache");
    } catch (e) {
      print("❌ Erreur chargement cache types: $e");
      propertyTypes = [];
    }
  }

  // ========== Features Methods ==========
  
  /// Sync features from API and cache locally
  Future<void> syncFeatures() async {
    loadingFeatures = true;
    notifyListeners();

    try {
      final url = "${Endpoints.features}"; // Correct endpoint
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      var response = await getData(url, token: tkn);

      if (response != null && response is Map<String, dynamic>) {
        dynamic featuresData;
        
        if (response.containsKey('data')) {
          featuresData = response['data'];
        } else if (response.containsKey('features')) {
          featuresData = response['features'];
        } else {
          featuresData = response;
        }

        if (featuresData is List && featuresData.isNotEmpty) {
          final List<Map<String, dynamic>> features = featuresData
              .where((e) => e != null)
              .map<Map<String, dynamic>>((e) => {
                    'featureId': e['featureId'],
                    'name': e['name'],
                  })
              .toList();

          // Save to local database
          final db = DatabaseHelper.instance;
          await db.insertFeatures(features);

          // Update in-memory list
          propertyFeatures = features;
          
          // Store sync timestamp
          stockage?.write('features_last_sync', DateTime.now().millisecondsSinceEpoch);
          
          print("✅ ${features.length} caractéristiques synchronisées");
        } else {
          print("⚠️ Aucune donnée de caractéristique trouvée");
          await _loadFeaturesFromCache();
        }
      } else {
        print("⚠️ Réponse invalide pour les caractéristiques");
        await _loadFeaturesFromCache();
      }
    } catch (e) {
      print("❌ Erreur sync caractéristiques: $e");
      await _loadFeaturesFromCache();
    } finally {
      loadingFeatures = false;
      notifyListeners();
    }
  }

  /// Get features (from memory, cache, or API)
  Future<List<Map<String, dynamic>>> getFeatures() async {
    // If already loaded in memory, return immediately
    if (propertyFeatures.isNotEmpty) {
      return propertyFeatures;
    }

    // Try to load from cache
    await _loadFeaturesFromCache();
    
    if (propertyFeatures.isNotEmpty) {
      // Check if cache is stale (older than 24 hours)
      final lastSync = stockage?.read<int>('features_last_sync');
      if (lastSync != null) {
        final age = DateTime.now().millisecondsSinceEpoch - lastSync;
        if (age < 86400000) { // 24 hours in milliseconds
          return propertyFeatures;
        }
      }
    }

    // Cache is empty or stale, sync from API
    await syncFeatures();
    return propertyFeatures;
  }

  /// Load features from local cache
  Future<void> _loadFeaturesFromCache() async {
    try {
      final db = DatabaseHelper.instance;
      propertyFeatures = await db.getAllFeatures();
      print("📦 ${propertyFeatures.length} caractéristiques chargées depuis le cache");
    } catch (e) {
      print("❌ Erreur chargement cache caractéristiques: $e");
      propertyFeatures = [];
    }
  }

}



void main() async {
  await GetStorage.init();
  var stockage = GetStorage();
  var ctrl = PropertyController(stockage: stockage);

  // Exemple d'utilisation
  ctrl.getAllProperty();

  // Pour forcer une synchronisation manuelle
  // ctrl.forceSync();

  // Pour vider le cache
  // ctrl.clearLocalCache();

  // Pour vérifier si une propriété spécifique existe en ligne
  // bool exists = await ctrl.isPropertyOnline(123);
}