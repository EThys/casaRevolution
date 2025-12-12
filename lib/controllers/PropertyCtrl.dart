import 'package:casa/utils/database/DatabaseHelper.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart';
import '../models/PropertyModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/Constantes.dart';
import '../utils/requetes.dart' show getData, postData, patchData, deleteData, putData, HttpResponse;

class PropertyController with ChangeNotifier {
  PropertyController({this.stockage});

  GetStorage? stockage;
  bool loading = false;
  bool syncing = false;
  List<PropertyModel> properties = [];
  List<PropertyModel> similarProperties = [];
  PropertyModel? currentProperty;

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

        // Vérifier que propertiesData est une List
        if (propertiesData is List && propertiesData.isNotEmpty) {
          List<PropertyModel> onlineProperties = propertiesData
              .where((e) => e != null) // Filtrer les éléments null
              .map<PropertyModel>((e) {
            try {
              return PropertyModel.fromJson(e);
            } catch (e) {
              print("Erreur lors du parsing d'une propriété: $e");
              // Retourner une propriété vide ou gérer l'erreur
              return PropertyModel(); // Assurez-vous que PropertyModel a un constructeur par défaut
            }
          })
              .where((property) => property.propertyId != null) // Filtrer les propriétés invalides
              .toList();

          // Synchroniser avec la base locale
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

  // Méthode pour synchroniser les données en ligne avec le cache local
  Future<void> _syncWithLocalDatabase(List<PropertyModel> onlineProperties) async {
    final db = DatabaseHelper.instance;

    // Récupérer toutes les propriétés locales
    final localProperties = await db.getAllProperties();

    // Identifier les propriétés supprimées en ligne
    final onlineIds = onlineProperties.map((p) => p.propertyId).toSet();
    final localIds = localProperties.map((p) => p.propertyId).toSet();

    // Supprimer les propriétés qui n'existent plus en ligne
    final deletedIds = localIds.difference(onlineIds);
    for (final id in deletedIds) {
      await db.deleteProperty(id!);
    }

    // Mettre à jour/insérer les propriétés en ligne
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

        if (response.containsKey('properties')) {
          propertiesData = response['properties'];
        } else if (response.containsKey('data')) {
          propertiesData = response['data'];
        } else {
          propertiesData = response;
        }

        // Cas API paginée: properties -> content
        if (propertiesData is Map && propertiesData.containsKey('content')) {
          propertiesData = propertiesData['content'];
        }

        if (propertiesData is List && propertiesData.isNotEmpty) {
          List<PropertyModel> onlineProperties = propertiesData
              .where((e) => e != null)
              .map<PropertyModel>((e) {
            try {
              return PropertyModel.fromJson(e);
            } catch (e) {
              print("Erreur parsing: $e");
              return PropertyModel();
            }
          }).where((property) => property.propertyId != null).toList();

          // Synchronisation intelligente basée sur le contenu
          await _smartSyncByContent(onlineProperties, forceSync: forceSync);
        } else {
          print("Aucune donnée valide en ligne");
        }
      }
    } catch (e) {
      print("Erreur lors du refresh: $e");
      _showErrorNotification("Impossible de rafraîchir les données");
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
    for (final id in toDelete) {
      await db.deleteProperty(id!);
      print("🗑️ Propriété $id supprimée");
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

  // Nouvelle méthode pour mettre à jour une propriété par owner
  Future<HttpResponse> updatePropertyByOwner(int userId, int propertyId, Map<String, dynamic> propertyData) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.propertiesByOwner}$userId/$propertyId";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      print("🔄 Mise à jour propriété: $url");
      print("📦 Données: ${propertyData.keys.toList()}");

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
    // Ne pas appeler notifyListeners() ici pour éviter setState pendant build
    // Il sera appelé après la récupération des données dans tous les cas
    
    try {
      // Récupérer le userId depuis GetStorage
      // Structure: {"user": {"userId": 57, ...}}
      final userData = stockage?.read(StockageKeys.userKey);
      String? userId;
      
      if (userData is Map) {
        // Si userData est directement un Map avec userId
        if (userData.containsKey('userId')) {
          userId = userData['userId']?.toString();
        } 
        // Si userData a une clé "user" qui contient userId
        else if (userData.containsKey('user') && userData['user'] is Map) {
          userId = userData['user']?['userId']?.toString();
        }
      }
      
      if (userId == null || userId.isEmpty) {
        print("❌ Aucun user ID trouvé pour récupérer les propriétés");
        print("📦 Données GetStorage userKey: $userData");
        loading = false;
        notifyListeners();
        return [];
      }

      print("✅ UserId récupéré: $userId");
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      // Endpoint: api/property/owner/{userId}
      final url = "${Endpoints.propertiesByOwner}$userId";
      print("🌐 URL de la requête: ${Constantes.BASE_URL}$url");
      var response = await getData(url, token: tkn);
      print("📡 Réponse API: $response");

      if (response != null && response is Map<String, dynamic>) {
        dynamic propertiesData;

        if (response.containsKey('properties')) {
          propertiesData = response['properties'];
        } else if (response.containsKey('data')) {
          propertiesData = response['data'];
        } else {
          propertiesData = response;
        }

        if (propertiesData is List && propertiesData.isNotEmpty) {
          List<PropertyModel> myProperties = propertiesData
              .where((e) => e != null)
              .map<PropertyModel>((e) {
                try {
                  final property = PropertyModel.fromJson(Map<String, dynamic>.from(e));
                  // Debug: Afficher le userId parsé pour chaque propriété
                  print("🏠 Property ${property.propertyId}: userId = ${property.userId} (attendu: $userId)");
                  return property;
                } catch (e) {
                  print("❌ Erreur parsing property: $e");
                  return PropertyModel();
                }
              })
              .where((p) => p.propertyId != null)
              .toList();

          print("📊 Avant filtrage: ${myProperties.length} propriétés");
          // Filtrer par userId pour être sûr
          myProperties = myProperties.where((p) {
            final matches = p.userId?.toString() == userId;
            if (!matches) {
              print("❌ Property ${p.propertyId} filtrée: userId=${p.userId} != $userId");
            }
            return matches;
          }).toList();
          print("✅ Après filtrage: ${myProperties.length} propriétés");

          // Mettre en cache local
          final db = DatabaseHelper.instance;
          for (final p in myProperties) {
            await db.insertOrUpdateProperty(p);
          }

          loading = false;
          notifyListeners();
          print("✅ ${myProperties.length} propriétés récupérées avec succès");
          return myProperties;
        }
      }

      print("⚠️ Aucune donnée trouvée dans la réponse API");
      // Si pas de données en ligne, retourner les propriétés filtrées localement
      await _loadFromCache();
      final myProperties = properties.where((p) => p.userId?.toString() == userId).toList();

      loading = false;
      notifyListeners();
      print("📦 ${myProperties.length} propriétés chargées depuis le cache");
      return myProperties;
    } catch (e) {
      print("❌ Erreur lors de la récupération des propriétés: $e");
      // En cas d'erreur, retourner les propriétés filtrées localement
      try {
        final userData = stockage?.read(StockageKeys.userKey);
        String? userId;
        
        if (userData is Map) {
          if (userData.containsKey('userId')) {
            userId = userData['userId']?.toString();
          } else if (userData.containsKey('user') && userData['user'] is Map) {
            userId = userData['user']?['userId']?.toString();
          }
        }
        
        if (userId != null) {
          await _loadFromCache();
          final myProperties = properties.where((p) => p.userId?.toString() == userId).toList();
          loading = false;
          notifyListeners();
          return myProperties;
        }
      } catch (cacheError) {
        print("❌ Erreur cache: $cacheError");
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
      if (typeMaison != null && property.propertyType != typeMaison) return false;

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