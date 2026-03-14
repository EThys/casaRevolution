import 'package:casa/models/PropertyFavoriteModel.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/database/FavoriteDatabaseHelper.dart';
import 'package:casa/utils/requetes.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_storage/get_storage.dart';

import '../utils/Endpoints.dart';
import 'package:casa/services/ServerHealthService.dart';

class PropertyFavoriteCtrl with ChangeNotifier {
  GetStorage? stockage;
  bool loading = false;

  List<PropertyFavoriteModel> propertyFavorites = [];
  final FavoriteDatabaseHelper _dbHelper = FavoriteDatabaseHelper.instance;

  PropertyFavoriteCtrl({this.stockage});

  Future<List<PropertyFavoriteModel>> getFavoritesByUser(String userId) async {
    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    // Main URL
    final urlMain = "${Endpoints.getMyfavorites}/$userId";
    
    // Specific URLs
    final urlHotel = "${Endpoints.favoriteHotelByUser}/$userId";
    final urlFestive = "${Endpoints.favoriteFestiveByUser}/$userId";
    final urlFuneraire = "${Endpoints.favoriteFuneraireByUser}/$userId";
    final urlTerrain = "${Endpoints.favoriteTerrainByUser}/$userId";
    final urlVacance = "${Endpoints.favoriteVacanceByUser}/$userId";
    final urlPrestation = "${Endpoints.favoritePrestationByUser}/$userId";
    final urlBureau = "${Endpoints.favoriteBureauByUser}/$userId";

    loading = true;
    notifyListeners();

    try {
      // 1. Lancer toutes les requêtes en parallèle
      final results = await Future.wait([
        getData(urlMain, token: tkn),       // 0: Main
        getData(urlHotel, token: tkn),      // 1: Hotel
        getData(urlFestive, token: tkn),    // 2: Festive
        getData(urlFuneraire, token: tkn),  // 3: Funeraire
        getData(urlTerrain, token: tkn),    // 4: Terrain
        getData(urlVacance, token: tkn),    // 5: Vacance
        getData(urlPrestation, token: tkn), // 6: Prestation
        getData(urlBureau, token: tkn),     // 7: Bureau
      ]);

      print("API Responses received: ${results.length}");
      propertyFavorites.clear();
      await _dbHelper.clearUserFavorites(userId);

      // 2. Parser chaque réponse et aggréger
      List<PropertyFavoriteModel> aggregatedFavorites = [];

      // Helper pour parser une réponse individuelle selon la structure (favorites/favorite/list/single)
      List<PropertyFavoriteModel> parseResponse(dynamic response, String source) {
        if (response == null) return [];
        if (response is Map && response.containsKey('status') && response['status'] == false) return [];
        
        List<PropertyFavoriteModel> parsed = [];
        try {
          List<dynamic>? list;
          if (response is Map) {
            final mapResponse = Map<String, dynamic>.from(response);
            
            // Priorité aux clés connues
            final knownKeys = [
              'favorites', 'favorite', 'terrain', 'bureau', 'bureaux', 
              'festive', 'festives', 'funeraire', 'funeraires', 
              'hotel', 'hotels', 'vacance', 'vacances', 
              'prestation', 'prestations', 'content', 'data'
            ];

            for (var key in knownKeys) {
              if (mapResponse[key] is List) {
                list = mapResponse[key];
                // print("📍 [$source] Found list under key: '$key' (${list?.length} items)");
                break;
              }
            }

            // Si aucune clé connue, chercher la PEMIÈRE liste trouvée dans le Map
            if (list == null) {
              for (var value in mapResponse.values) {
                if (value is List) {
                  list = value;
                  // print("📍 [$source] Found list under unknown key (${list.length} items)");
                  break;
                }
              }
            }

            // Si c'est un objet unique (favori seul ou propriété seule)
            if (list == null) {
              if (mapResponse.containsKey('propertyId') || mapResponse.containsKey('id') || mapResponse.containsKey('title')) {
                final fav = PropertyFavoriteModel.fromJson(mapResponse);
                if (fav.property != null) parsed.add(fav);
              } else if (mapResponse['favorite'] is Map) {
                 final fav = PropertyFavoriteModel.fromJson(Map<String, dynamic>.from(mapResponse['favorite']));
                 if (fav.property != null) parsed.add(fav);
              }
            }
          } else if (response is List) {
            list = response;
          }

          if (list != null) {
            for (var item in list) {
              if (item is Map) {
                final fav = PropertyFavoriteModel.fromJson(Map<String, dynamic>.from(item));
                // Accepter si property OU prestation a pu être construit
                if ((fav.property != null && fav.property!.propertyId != null) ||
                    (fav.prestation != null && fav.prestation!.id != null)) {
                  parsed.add(fav);
                }
              }
            }
          }
        } catch (e) {
          print("Error parsing response subset from $source: $e");
        }
        
        if (parsed.isNotEmpty) {
          print("✅ [$source] Found ${parsed.length} favorites");
        } else if (response != null) {
          // print("ℹ️ [$source] No favorites found in response");
        }
        return parsed;
      }

      // 3. Aggréger
      final sources = [
        "Main", "Hotel", "Festive", "Funeraire", "Terrain", "Vacance", "Prestation", "Bureau"
      ];
      
      for (int i = 0; i < results.length; i++) {
        aggregatedFavorites.addAll(parseResponse(results[i], sources[i]));
      }

      print("Total aggregated favorites from API: ${aggregatedFavorites.length}");

      // 4. Sauvegarder en local
      for (var fav in aggregatedFavorites) {
        await _dbHelper.insertOrUpdateFavorite(fav, userId);
      }

      // 5. Trier par ID décroissant pour avoir le dernier ajouté au dessus
      aggregatedFavorites.sort((a, b) {
        int idA = a.propertyFavoriteId ?? 0;
        int idB = b.propertyFavoriteId ?? 0;
        return idB.compareTo(idA);
      });

      propertyFavorites = aggregatedFavorites;

    } catch (e) {
      print("Error fetching all favorites: $e");
      // Fallback local
      try {
        final localFavorites = await _dbHelper.getFavoritesByUser(userId);
        propertyFavorites = localFavorites;
        print("Chargement depuis la base locale (Fallback): ${localFavorites.length} favoris");
      } catch (dbError) {
        print("Error loading from local database: $dbError");
      }
    }

    loading = false;
    notifyListeners();
    return propertyFavorites;
  }



  // Méthode pour synchroniser la file d'attente hors ligne
  Future<void> syncOfflineQueue(String userId) async {
    // 1. Vérifier si le serveur est connu comme étant hors ligne
    if (ServerHealthService().isServerDown) {
      print("🛑 [PropertyFavoriteCtrl] Serveur marqué DOWN par HealthService -> sync annulé/reporté");
      return;
    }

    final queue = await _dbHelper.getQueue(userId);
    if (queue.isEmpty) return;

    print("🔄 [PropertyFavoriteCtrl] Traitement de la file d'attente (${queue.length} éléments)...");
    
    // Flag pour arrêter si urgence serveur
    bool abortSync = false;

    for (var item in queue) {
      if (abortSync) break;

      final id = item['id'] as int;
      final propertyId = item['propertyId'] as String;
      final action = item['action'] as String;
      final propertyTypeId = item['propertyTypeId'] as int?;
      
      // THROTTLING: Petit délai pour ne pas spammer le serveur
      await Future.delayed(Duration(milliseconds: 1000));

      bool success = false;
      try {
        if (action == 'ADD') {
          success = await _performAddFavoriteApi(userId, propertyId, propertyTypeId: propertyTypeId);
        } else if (action == 'REMOVE') {
          success = await _performRemoveFavoriteApi(userId, propertyId, propertyTypeId: propertyTypeId);
        }
        
        if (success) {
          await _dbHelper.removeFromQueue(id);
          print("✅ [PropertyFavoriteCtrl] Élément de file traité et supprimé: $action $propertyId (Type: $propertyTypeId)");
        }
      } catch (e) {
        print("❌ [PropertyFavoriteCtrl] Échec synchro item $id: $e");
        
        // Gérer les erreurs critiques pour arrêter le massacre
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('429') || // Too Many Requests
            errorStr.contains('500') || // Internal Server Error
            errorStr.contains('503') || // Service Unavailable
            errorStr.contains('refused') || // Connection refused (still down)
            errorStr.contains('timed out')) {
           
           print("🛑 [PropertyFavoriteCtrl] Erreur critique/Serveur ($errorStr) -> Arrêt de la synchro");
           abortSync = true;
        }
      }
    }
    
    // Rafraîchir la liste finale
    if (!abortSync) {
        await getFavoritesByUser(userId);
    }
  }

  // API Call interne sans logique de queue
  Future<bool> _performAddFavoriteApi(String userId, String propertyId, {int? propertyTypeId, bool isPrestation = false}) async {
    final token = stockage?.read<String>(StockageKeys.tokenKey);
    if (token == null) throw Exception('Token non disponible');
    
    String url = Endpoints.AddFavorite;
    Map<String, dynamic> data = {};
    final uid = int.tryParse(userId);
    final pid = int.tryParse(propertyId);

    // Si c'est une prestation, on utilise l'endpoint et le body spécifiques
    if (isPrestation) {
      url = Endpoints.AddfavoritePrestation;
      data = {
        "userId": uid,
        "prestationId": pid,
      };
    } else {
      // Pour les propriétés classiques
      data = {
        "userId": uid,
        "propertyId": pid,
      };

      if (propertyTypeId != null) {
         switch (propertyTypeId) {
           case 4: // Bureau
             url = Endpoints.favoriteBureau;
             data = {"userId": uid, "bureauId": pid};
             break;
           case 5: // Hotel
             url = Endpoints.favoriteHotel;
             data = {"userId": uid, "hotelId": pid};
             break;
           case 7: // Funeraire
             url = Endpoints.favoriteFuneraire;
             data = {"userId": uid, "funeraireId": pid};
             break;
           case 8: // Festive
             url = Endpoints.favoriteFestive;
             data = {"userId": uid, "festId": pid};
             break;
           case 9: // Terrain
             url = Endpoints.favoriteTerrain;
             data = {"userId": uid, "terrainId": pid};
             break;
           case 11: // Vacance
              url = Endpoints.favoriteVacance;
              data = {"userId": uid, "vacanceId": pid};
              break;
         }
      }
    }
    
    print("AddFavorite: $url with body $data");
    final response = await postData(url, data, token: token);
    
    if (response.status == true) return true;
    if (response.data != null && 
        response.data is Map && 
        response.data['message'] != null &&
        response.data['message'].toString().toLowerCase().contains('déjà')) {
        return true;
    }
    return false;
  }

  Future<bool> _performRemoveFavoriteApi(String userId, String propertyId, {int? propertyTypeId, bool isPrestation = false}) async {
    final token = stockage?.read<String>(StockageKeys.tokenKey);
    if (token == null) throw Exception('Token non disponible');
    
    String url;
    final uid = int.tryParse(userId);
    final pid = int.tryParse(propertyId);
    
    if (isPrestation) {
      // DELETE /api/{version}/protected/prestation/favorite/{id}
      // pid = l'ID de la prestation (favoriteId)
      url = "${Endpoints.favoritePrestationDelete}/$pid";
    } else {
      // Utiliser l'endpoint spécifique selon le type pour les propriétés classiques
      if (propertyTypeId != null) {
        switch (propertyTypeId) {
          case 4: // Bureau
            url = "${Endpoints.favoriteBureauDelete}/$uid/$pid";
            break;
          case 5: // Hotel
            url = "${Endpoints.favoriteHotelDelete}/$uid/$pid";
            break;
          case 8: // Festive
            url = "${Endpoints.favoriteFestiveDelete}/$uid/$pid";
            break;
          case 7: // Funeraire
            url = "${Endpoints.favoriteFuneraireDelete}/$uid/$pid";
            break;
          case 9: // Terrain
            url = "${Endpoints.favoriteTerrainDelete}/$uid/$pid";
            break;
          case 11: // Vacance
            url = "${Endpoints.favoriteVacanceDelete}/$uid/$pid";
            break;
          default:
            url = "${Endpoints.removeMyfavorites}/$uid/$pid";
        }
      } else {
        url = "${Endpoints.removeMyfavorites}/$uid/$pid";
      }
    }

    print("🗑️ [PropertyFavoriteCtrl] Appel API DELETE: $url");
    final response = await deleteData(url, token: token);
    
    if (response.status == true) return true;
    
    print("⚠️ [PropertyFavoriteCtrl] API Detail: Status=${response.status}, Data=${response.data}");
    
    if (response.data != null && response.data is Map) {
         final msg = response.data['message']?.toString().toLowerCase() ?? '';
         if (msg.contains('deleted') || msg.contains('success')) return true;
         if (msg.contains('not found') || msg.contains('aucun')) {
           print("ℹ️ [PropertyFavoriteCtrl] Déjà supprimé ou inexistant sur le serveur");
           return true; 
         }
    }
    return false;
  }

  Future<bool> addFavorite(String userId, String propertyId, {int? propertyTypeId, bool isPrestation = false}) async {
    print("❤️ [PropertyFavoriteCtrl] Début addFavorite - userId: $userId, propertyId: $propertyId, type: $propertyTypeId, isPrestation: $isPrestation");
    
    try {
      final success = await _performAddFavoriteApi(userId, propertyId, propertyTypeId: propertyTypeId, isPrestation: isPrestation);
      
      if (success) {
        print("✅ [PropertyFavoriteCtrl] API Success: Favorite added");
        return true;
      } else {
        throw Exception("API a retourné false");
      }

    } catch (e) {
      print("⚠️ [PropertyFavoriteCtrl] Erreur API lors de l'ajout: $e");
      
      bool isNetworkError = e.toString().contains("SocketException") || 
                           e.toString().contains("ClientException") ||
                           e.toString().contains("Connection refused") ||
                           e.toString().contains("Network is unreachable");

      if (isNetworkError) {
        print("🌐 [PropertyFavoriteCtrl] Mode Offline détecté: Mise en file d'attente ADD (Type: $propertyTypeId)");
        await _dbHelper.enqueueAction(userId, propertyId, 'ADD', propertyTypeId: propertyTypeId);
        return true;
      }
      rethrow;
    }
  }

  Future<bool> removeFavorite(String userId, String propertyId, {int? propertyTypeId, bool isPrestation = false}) async {
    print("🗑️ [PropertyFavoriteCtrl] Début removeFavorite - userId: $userId, propertyId: $propertyId, type: $propertyTypeId, isPrestation: $isPrestation");

    try {
      // Suppression locale immédiate (déjà géré par Provider en optimiste, mais on nettoie la DB local)
      await _dbHelper.removeFavorite(userId, propertyId);
      
      // Appel API
      final success = await _performRemoveFavoriteApi(userId, propertyId, propertyTypeId: propertyTypeId, isPrestation: isPrestation);
      
      if (success) {
        print("✅ [PropertyFavoriteCtrl] Suppression API réussie");
        return true;
      } else {
        throw Exception("API a retourné false");
      }
    } catch (e) {
      print("⚠️ [PropertyFavoriteCtrl] Erreur API lors de suppression: $e");
      
      bool isNetworkError = e.toString().contains("SocketException") || 
                           e.toString().contains("ClientException") ||
                           e.toString().contains("Connection refused");

      if (isNetworkError) {
        print("🌐 [PropertyFavoriteCtrl] Mode Offline détecté: Mise en file d'attente REMOVE (Type: $propertyTypeId)");
        await _dbHelper.enqueueAction(userId, propertyId, 'REMOVE', propertyTypeId: propertyTypeId);
        return true; // Succès optimiste
      }
      
      rethrow;
    }
  }

  // Méthode pour vider les favoris locaux
  void clearLocalFavorites() {
    propertyFavorites.clear();
    notifyListeners();
  }

  // Méthode pour vérifier si une propriété est en favoris
  bool isPropertyFavorite(String propertyId) {
    return propertyFavorites.any((fav) =>
    fav.property?.propertyId.toString() == propertyId);
  }
}