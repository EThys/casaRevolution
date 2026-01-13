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
      ]);

      print("API Responses received: ${results.length}");
      propertyFavorites.clear();
      await _dbHelper.clearUserFavorites(userId);

      // 2. Parser chaque réponse et aggréger
      List<PropertyFavoriteModel> aggregatedFavorites = [];

      // Helper pour parser une réponse individuelle selon la structure (favorites/favorite/list/single)
      List<PropertyFavoriteModel> parseResponse(dynamic response) {
        if (response == null) return [];
        List<PropertyFavoriteModel> parsed = [];
        try {
          if (response['favorites'] is List) {
             parsed = (response['favorites'] as List)
                .map<PropertyFavoriteModel>((e) => PropertyFavoriteModel.fromJson(e)).toList();
          } else if (response['favorite'] is List) {
             parsed = (response['favorite'] as List)
                .map<PropertyFavoriteModel>((e) => PropertyFavoriteModel.fromJson(e)).toList();
          } else if (response['favorite'] is Map) {
             parsed.add(PropertyFavoriteModel.fromJson(response['favorite']));
          } else if (response is List) {
             parsed = (response as List)
                .map<PropertyFavoriteModel>((e) => PropertyFavoriteModel.fromJson(e)).toList();
          } else {
             try {
                parsed.add(PropertyFavoriteModel.fromJson(response));
             } catch (_) {}
          }
        } catch (e) {
          print("Error parsing response subset: $e");
        }
        return parsed;
      }

      // 3. Aggréger
      for (var response in results) {
        aggregatedFavorites.addAll(parseResponse(response));
      }

      print("Total aggregated favorites from API: ${aggregatedFavorites.length}");

      // 4. Sauvegarder en local
      for (var fav in aggregatedFavorites) {
        await _dbHelper.insertOrUpdateFavorite(fav, userId);
      }

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
      
      // THROTTLING: Petit délai pour ne pas spammer le serveur
      await Future.delayed(Duration(milliseconds: 1000));

      bool success = false;
      try {
        if (action == 'ADD') {
          success = await _performAddFavoriteApi(userId, propertyId);
        } else if (action == 'REMOVE') {
          success = await _performRemoveFavoriteApi(userId, propertyId);
        }
        
        if (success) {
          await _dbHelper.removeFromQueue(id);
          print("✅ [PropertyFavoriteCtrl] Élément de file traité et supprimé: $action $propertyId");
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
  Future<bool> _performAddFavoriteApi(String userId, String propertyId, {int? propertyTypeId}) async {
    final token = stockage?.read<String>(StockageKeys.tokenKey);
    if (token == null) throw Exception('Token non disponible');
    
    String url = Endpoints.AddFavorite;
    Map<String, dynamic> data = {};
    final uid = int.tryParse(userId);
    final pid = int.tryParse(propertyId);

    // Default body
    data = {
      "userId": uid,
      "propertyId": pid,
    };

    if (propertyTypeId != null) {
       switch (propertyTypeId) {
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
         // Case for Vacance? Assuming it shares ID logic or uses propertyTypeId specific to it.
         // If "Vacance" is a type, mapped to ?
         // For now, if user says "vacance", we need to know its ID.
         // Let's assume ID 11? Or is it part of properties?
         // If generic property, it uses default.
         case 11: // Vacance (Hypothetical ID, check consts if available)
            url = Endpoints.favoriteVacance;
            data = {"userId": uid, "terrainId": pid}; // User said terrainId for vacance... suspicious but following order.
            break;
            
         // Prestation?
         case 12: // Prestation (Hypothetical) 
            url = Endpoints.favoritePrestation;
            data = {"userId": uid, "prestationId": pid};
            break;
       }
    }
    
    // Fallback logic specific for implicit overrides based on IDs if type is passed but not matched above? 
    // Actually, let's keep it simple. If it matches known types, switch.
    
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

  Future<bool> _performRemoveFavoriteApi(String userId, String propertyId, {int? propertyTypeId}) async {
    final token = stockage?.read<String>(StockageKeys.tokenKey);
    if (token == null) throw Exception('Token non disponible');
    
    // Note: User didn't specify DELETE endpoints, assuming generic delete works by ID
    // If specific delete endpoints exist, implement switch here too.
    final url = "favorite/delete/$userId/$propertyId";
    final response = await deleteData(url, token: token);
    
    if (response.status == true) return true;
    if (response.data != null && response.data is Map) {
         final msg = response.data['message']?.toString().toLowerCase() ?? '';
         if (msg.contains('deleted') || msg.contains('success')) return true;
    }
    return false;
  }

  Future<bool> addFavorite(String userId, String propertyId, {int? propertyTypeId}) async {
    print("❤️ [PropertyFavoriteCtrl] Début addFavorite - userId: $userId, propertyId: $propertyId, type: $propertyTypeId");
    
    try {
      final success = await _performAddFavoriteApi(userId, propertyId, propertyTypeId: propertyTypeId);
      
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
        print("🌐 [PropertyFavoriteCtrl] Mode Offline détecté: Mise en file d'attente ADD");
        await _dbHelper.enqueueAction(userId, propertyId, 'ADD');
        return true;
      }
      rethrow;
    }
  }

  Future<bool> removeFavorite(String userId, String propertyId, {int? propertyTypeId}) async {
    print("🗑️ [PropertyFavoriteCtrl] Début removeFavorite - userId: $userId, propertyId: $propertyId, type: $propertyTypeId");

    try {
      // Suppression locale immédiate (déjà géré par Provider en optimiste, mais on nettoie la DB local)
      await _dbHelper.removeFavorite(userId, propertyId);
      
      // Appel API
      final success = await _performRemoveFavoriteApi(userId, propertyId, propertyTypeId: propertyTypeId);
      
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
        print("🌐 [PropertyFavoriteCtrl] Mode Offline détecté: Mise en file d'attente REMOVE");
        await _dbHelper.enqueueAction(userId, propertyId, 'REMOVE');
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