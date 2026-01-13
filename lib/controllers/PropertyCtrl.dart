import 'dart:convert';
import 'package:casa/utils/database/DatabaseHelper.dart';
import 'package:casa/utils/TerrainDatabaseHelper.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart';
import '../models/PropertyModel.dart';
import '../models/PropertyTypeModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/Constantes.dart';
import '../utils/requetes.dart' show getData, postData, patchData, deleteData, putData, HttpResponse;
import '../models/DeviseModel.dart';

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
  List<Map<String, dynamic>> terrains = [];
  bool loadingSpecial = false;

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
      var response = await getData("${Constantes.URL_BASE}${Endpoints.devises}", token: token);
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

      // Vérification plus robuste du type de réponse
      if (response != null && response is Map<String, dynamic>) {
        // Vérifier les différentes structures possibles de réponse
        dynamic propertiesData;

        if (response.containsKey('properties')) {
          propertiesData = response['properties'];
        } else if (response.containsKey('data')) {
          propertiesData = response['data'];
        } else {
          // Si la structure est différente, utiliser la réponse entière
          propertiesData = response;
        }

        // Cas API paginée: properties -> content
        if (propertiesData is Map && propertiesData.containsKey('content')) {
          propertiesData = propertiesData['content'];
        }

        // Check if propertiesData is a List
        if (propertiesData is List) {
          List<PropertyModel> onlineProperties = propertiesData
              .where((e) => e != null) // Filtrer les éléments null
              .map<PropertyModel>((e) {
            try {
              return PropertyModel.fromJson(e);
            } catch (e) {
              print("Erreur lors du parsing d'une propriété: $e");
              return PropertyModel();
            }
          })
              .where((property) => property.propertyId != null) // Filtrer les propriétés invalides
              .toList();

          // Synchroniser avec la base locale (sera vidée si onlineProperties est vide)
          await _syncWithLocalDatabase(onlineProperties);

          // Mettre à jour la liste en mémoire
          properties = onlineProperties;
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
      // En cas d'erreur, charger depuis le cache
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
    
    // Fusionner les données locales dans la liste principale immédiatement
    _mergeIntoMainProperties(bureaux);
    _mergeIntoMainProperties(festives);
    _mergeIntoMainProperties(funeraires);
    
    // Si on a des données locales, on affiche tout de suite (pas de loader bloquant)
    if (bureaux.isNotEmpty || festives.isNotEmpty || funeraires.isNotEmpty) {
       notifyListeners();
    } else {
       // Sinon on montre le loader
       loadingSpecial = true;
       notifyListeners();
    }

    try {
      // 2. Synchronisation en arrière-plan (sans bloquer l'UI)
      // On lance les appels en parallèle pour aller plus vite, ou séquentiel si on veut limiter la charge
      await Future.wait([
        _syncSpecialCategory(Endpoints.propertyBureaux, DatabaseHelper.tableBureaux, (list) => bureaux = list),
        _syncSpecialCategory(Endpoints.propertyFestives, DatabaseHelper.tableFestives, (list) => festives = list),
        _syncSpecialCategory(Endpoints.propertyFuneraires, DatabaseHelper.tableFuneraires, (list) => funeraires = list),
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
        else rawData = response['data'];

        print("📡 [$tableName] Response keys: ${response.keys}");
        if (rawData != null && rawData is List) {
          print("📦 [$tableName] Raw items found: ${rawData.length}");
          final List<PropertyModel> onlineList = [];
          for (var e in rawData) {
            try {
              final p = PropertyModel.fromJson(e);
              
              if (tableName == DatabaseHelper.tableBureaux) {
                 p.propertyTypeId = 4;
                 p.propertyType = PropertyTypeModel(propertyTypeId: 4, name: 'Bureau');
              } else if (tableName == DatabaseHelper.tableFestives) {
                 p.propertyTypeId = 8;
                 p.propertyType = PropertyTypeModel(propertyTypeId: 8, name: 'Salle de fête');
              } else if (tableName == DatabaseHelper.tableFuneraires) {
                 p.propertyTypeId = 7;
                 p.propertyType = PropertyTypeModel(propertyTypeId: 7, name: 'Salle funéraires');
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
             _mergeIntoMainProperties(onlineList); // Update main memory list too
          } else {
             print("✅ [$tableName] Local data is up-to-date. Using local.");
             updateList(localList); // Ensure memory uses the (verified valid) local list
             _mergeIntoMainProperties(localList);
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

  /// Load terrains from local cache
  Future<void> _loadTerrainsFromCache() async {
    try {
      final db = TerrainDatabaseHelper.instance;
      final cachedTerrains = await db.getAllTerrains();
      terrains = cachedTerrains;
      print("📦 [PropertyCtrl] ${terrains.length} terrains chargés depuis le cache local");
    } catch (e) {
      print("⚠️ [PropertyCtrl] Erreur lors du chargement des terrains depuis le cache: $e");
      terrains = [];
    }
  }

  /// Sync terrains with API and local database
  Future<void> _syncTerrainCategory() async {
    try {
      final response = await getData(Endpoints.propertyTerrains);
      if (response != null && response is Map<String, dynamic>) {
        final rawData = response['terrain'];
        if (rawData != null && rawData is List) {
          final List<Map<String, dynamic>> terrainList = rawData.cast<Map<String, dynamic>>();
          
          // Store in local database
          final db = TerrainDatabaseHelper.instance;
          await db.insertTerrains(terrainList);
          
          // Update in-memory list
          terrains = terrainList;
          
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
              return PropertyModel.fromJson(e);
            } catch (e) {
              return PropertyModel();
            }
          })
              .where((property) => property.propertyId != null)
              .toList();

          await _syncWithLocalDatabase(onlineProperties);
          properties = onlineProperties;
        } else {
          print("⚠️ Réponse properties vide ou invalide");
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
      print("✅ Aucun changement détecté, utilisation du cache");
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
      print("📊 Différence de nombre: local=${local.length}, online=${online.length}");
      return true;
    }

    // 2. Vérification des IDs
    final localIds = local.map((p) => p.propertyId).toSet();
    final onlineIds = online.map((p) => p.propertyId).toSet();

    final missingInLocal = onlineIds.difference(localIds);
    final missingInOnline = localIds.difference(onlineIds);

    if (missingInLocal.isNotEmpty || missingInOnline.isNotEmpty) {
      print("🆔 Différence d'IDs: +${missingInLocal.length}, -${missingInOnline.length}");
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
        print("📝 Propriété ${onlineProp.propertyId} a changé");
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

    print("🔄 Sync terminée: +$insertedCount nouveau, $updatedCount modifié, ${toDelete.length} supprimé");
  }

  // Méthode pour forcer une synchronisation complète
  Future<void> forceFullSync() async {
    await refreshProperties(forceSync: true);
  }

  void _logSyncEvent(int onlineCount, int localCount, bool hadChanges) {
    print("📊 Sync - En ligne: $onlineCount, Local: $localCount, Changements: $hadChanges");
  }

  void _showErrorNotification(String message) {
    // Cette méthode sera utilisée par l'UI pour afficher les erreurs
    print("❌ $message");
  }





  Future<List<PropertyModel>> getAllProperty() async {
    loading = true;
    notifyListeners();

    try {
      // Essayer d'abord de synchroniser avec les données en ligne
      await syncProperties();
      return properties;
    } catch (e) {
      print("Erreur lors du chargement: $e");
      // En cas d'erreur, charger depuis le cache
      await _loadFromCache();
      return properties;
    } finally {
      loading = false;
      notifyListeners();
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

  Future<PropertyModel?> getPropertyById(int propertyId) async {
    loading = true;
    notifyListeners();

    try {
      // Essayer d'abord de récupérer depuis l'API
      var url = "${Endpoints.properties}/$propertyId";
      var response = await getData(url);

      if (response != null) {
        // Nouvelle structure: { properties: {...}, similaires: [...] }
        dynamic propertyJson;
        dynamic similarJson;

        if (response is Map<String, dynamic>) {
          if (response['properties'] != null) {
            propertyJson = response['properties'];
          } else if (response['data'] != null) {
            propertyJson = response['data'];
          }
          if (response['similaires'] != null) {
            similarJson = response['similaires'];
          }
        }

        if (propertyJson != null) {
          PropertyModel property = PropertyModel.fromJson(Map<String, dynamic>.from(propertyJson));
          currentProperty = property;

          // Similar properties
          if (similarJson is List) {
            similarProperties = similarJson
                .where((e) => e != null)
                .map<PropertyModel>((e) {
                  try {
                    return PropertyModel.fromJson(Map<String, dynamic>.from(e));
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
      currentProperty = cachedProperty;
      similarProperties = [];
      loading = false;
      notifyListeners();
      return cachedProperty;
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

      final url = Endpoints.properties;
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

      final url = Endpoints.propertyBureaux;
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

  Future<HttpResponse> createFuneraire(Map<String, dynamic> funeraireData) async {
    try {
      loading = true;
      notifyListeners();

      print("⚰️ Envoi de la requête createFuneraire...");
      print("📊 Données envoyées: ${funeraireData.keys.toList()}");

      final url = Endpoints.propertyFuneraires; 
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

      final url = Endpoints.propertyFestives;
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

      final url = Endpoints.propertyVacances;
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

      final url = Endpoints.propertyTerrains;
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

  // Nouvelle méthode pour mettre à jour une propriété par owner
  Future<HttpResponse> updatePropertyByOwner(int userId, int propertyId, Map<String, dynamic> propertyData) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.propertiesByOwner}$userId/$propertyId";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      print("🔄 Mise à jour propriété: $url");
      print("📤 PAYLOAD COMPLET: ${jsonEncode(propertyData)}");

      HttpResponse response = await putData(url, propertyData, token: tkn);

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
        "property/bureaux/owner/$userId",
        "property/festives/owner/$userId",
        "property/funeraires/owner/$userId",
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
                      if (url.contains('bureaux')) property.propertyTypeId = 4;
                      else if (url.contains('festives')) property.propertyTypeId = 8;
                      else if (url.contains('funeraires')) property.propertyTypeId = 7;
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
    int size = 20,
    String sortBy = 'title',
    String sortOrder = 'asc',
  }) async {
    try {
      loading = true;
      notifyListeners();
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
      HttpResponse response = await getData(url, token: tkn);

      if (response.status == true && response.data != null) {
        dynamic propertiesData;

        if (response.data.containsKey('properties')) {
          propertiesData = response.data['properties'];
        } else if (response.data.containsKey('data')) {
          propertiesData = response.data['data'];
        } else if (response.data.containsKey('content')) {
          propertiesData = response.data['content']; // Pour la pagination Spring
        } else {
          propertiesData = response.data;
        }

        // Convertir en liste de PropertyModel
        if (propertiesData is List && propertiesData.isNotEmpty) {
          List<PropertyModel> filteredProperties = propertiesData
              .where((e) => e != null)
              .map<PropertyModel>((e) {
            try {
              return PropertyModel.fromJson(e);
            } catch (e) {
              print("Erreur lors du parsing d'une propriété filtrée: $e");
              return PropertyModel();
            }
          })
              .where((property) => property.propertyId != null)
              .toList();

          // Mettre à jour la liste des propriétés avec les résultats filtrés
          properties = filteredProperties;

          print("✅ Filtrage réussi: ${filteredProperties.length} propriétés trouvées");
        } else {
          print("ℹ️ Aucune propriété trouvée avec les critères spécifiés");
          properties = []; // Vider la liste si aucun résultat
        }
      } else {
        print("❌ Erreur lors du filtrage: ${response.errorMsg}");
        // En cas d'erreur, charger depuis le cache local avec les mêmes critères
        await _filterLocalProperties(
          sold: sold,
          minPrice: minPrice,
          maxPrice: maxPrice,
          typeMaison: typeMaison,
          city: city,
          commune: commune,
          room: room,
        );
      }

      loading = false;
      notifyListeners();
      return response;

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
    final allProperties = await db.getAllProperties();

    // Appliquer les filtres
    List<PropertyModel> filtered = allProperties.where((property) {
      // Filtre sold
      if (sold != null && property.sold != sold) return false;

      // Filtre prix minimum
      if (minPrice != null && (property.price ?? 0) < minPrice) return false;

      // Filtre prix maximum
      if (maxPrice != null && (property.price ?? double.maxFinite) > maxPrice) return false;

      // Filtre type de maison
      if (typeMaison != null && property.propertyTypeId != typeMaison) return false;


      // Filtre ville
      if (city != null && property.cityId != city) return false;

      // Filtre commune
      if (commune != null && property.communeId != commune) return false;

      // Filtre nombre de pièces
      if (room != null && property.rooms != room) return false;

      return true;
    }).toList();

    properties = filtered;
    print("🔍 Filtrage local: ${filtered.length} propriétés trouvées");
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
    await getAllProperty();
  }

  // Méthode pour rechercher par texte (titre, description, etc.)
  Future<HttpResponse> searchProperties(String searchTerm) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.propertySearch}?query=${Uri.encodeComponent(searchTerm)}";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await getData(url, token: tkn);

      if (response.status == true && response.data != null) {
        dynamic propertiesData;

        if (response.data.containsKey('properties')) {
          propertiesData = response.data['properties'];
        } else if (response.data.containsKey('data')) {
          propertiesData = response.data['data'];
        } else {
          propertiesData = response.data;
        }

        if (propertiesData is List && propertiesData.isNotEmpty) {
          List<PropertyModel> searchResults = propertiesData
              .where((e) => e != null)
              .map<PropertyModel>((e) => PropertyModel.fromJson(e))
              .where((property) => property.propertyId != null)
              .toList();

          properties = searchResults;
          print("🔍 Recherche réussie: ${searchResults.length} résultats pour '$searchTerm'");
        } else {
          properties = [];
          print("ℹ️ Aucun résultat pour la recherche: '$searchTerm'");
        }
      }

      loading = false;
      notifyListeners();
      return response;

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
    final allProperties = await db.getAllProperties();

    final searchResults = allProperties.where((property) {
      final term = searchTerm.toLowerCase();

      // Rechercher dans le titre
      if (property.title?.toLowerCase().contains(term) == true) return true;

      // Rechercher dans la description
      if (property.description?.toLowerCase().contains(term) == true) return true;

      // Rechercher dans l'adresse
      if (property.address?.toLowerCase().contains(term) == true) return true;

      return false;
    }).toList();

    properties = searchResults;
    print("🔍 Recherche locale: ${searchResults.length} résultats pour '$searchTerm'");
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
      final url = "${Endpoints.properties}/features"; // Correct endpoint
      var response = await getData(url);

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