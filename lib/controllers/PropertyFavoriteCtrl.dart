import 'package:casa/models/PropertyFavoriteModel.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/database/FavoriteDatabaseHelper.dart';
import 'package:casa/utils/requetes.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_storage/get_storage.dart';

import '../utils/Endpoints.dart';

class PropertyFavoriteCtrl with ChangeNotifier {
  GetStorage? stockage;
  bool loading = false;

  List<PropertyFavoriteModel> propertyFavorites = [];
  final FavoriteDatabaseHelper _dbHelper = FavoriteDatabaseHelper.instance;

  PropertyFavoriteCtrl({this.stockage});

  Future<List<PropertyFavoriteModel>> getFavoritesByUser(String userId) async {
    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    final url = "${Endpoints.getMyfavorites}/$userId";

    loading = true;
    notifyListeners();

    try {
      final response = await getData(url, token: tkn);
      print("API Response: $response");

      // Réinitialiser la liste avant de la remplir
      propertyFavorites.clear();

      if (response != null) {
        await _dbHelper.clearUserFavorites(userId);

        List<PropertyFavoriteModel> favorites = [];

        // ANALYSE DE LA RÉPONSE - Plusieurs cas possibles
        if (response['favorites'] is List) {
          // Cas 1: La réponse contient une liste 'favorites'
          print("Structure: Liste de favoris dans 'favorites'");
          favorites = (response['favorites'] as List)
              .map<PropertyFavoriteModel>((e) => PropertyFavoriteModel.fromJson(e))
              .toList();
        }
        else if (response['favorite'] is List) {
          // Cas 2: La réponse contient une liste 'favorite'
          print("Structure: Liste de favoris dans 'favorite'");
          favorites = (response['favorite'] as List)
              .map<PropertyFavoriteModel>((e) => PropertyFavoriteModel.fromJson(e))
              .toList();
        }
        else if (response['favorite'] is Map) {
          // Cas 3: La réponse contient un seul favori dans 'favorite'
          print("Structure: Un seul favori dans 'favorite'");
          final favorite = PropertyFavoriteModel.fromJson(response['favorite']);
          favorites.add(favorite);
        }
        else if (response is List) {
          // Cas 4: La réponse est directement une liste
          print("Structure: Réponse directe en liste");
          favorites = (response as List)
              .map<PropertyFavoriteModel>((e) => PropertyFavoriteModel.fromJson(e))
              .toList();
        }
        else {
          // Cas 5: Essayer de parser la réponse directement
          print("Structure: Essai de parsing direct");
          try {
            final favorite = PropertyFavoriteModel.fromJson(response);
            favorites.add(favorite);
          } catch (e) {
            print("Échec du parsing direct: $e");
          }
        }

        print("Nombre de favoris extraits: ${favorites.length}");

        // Sauvegarder en base locale
        for (var fav in favorites) {
          await _dbHelper.insertOrUpdateFavorite(fav, userId);
        }

        propertyFavorites = favorites;
      } else {
        print("Réponse API nulle ou vide");
      }

    } catch (e) {
      print("Error fetching favorites from API: $e");

      // Fallback sur la base de données locale en cas d'erreur
      try {
        final localFavorites = await _dbHelper.getFavoritesByUser(userId);
        propertyFavorites = localFavorites;
        print("Chargement depuis la base locale: ${localFavorites.length} favoris");
      } catch (dbError) {
        print("Error loading from local database: $dbError");
      }
    }

    loading = false;
    notifyListeners();

    print("Total des favoris chargés: ${propertyFavorites.length}");
    return propertyFavorites;
  }

  Future<bool> addFavorite(String userId, String propertyId) async {
    print("❤️ [PropertyFavoriteCtrl] Début addFavorite - userId: $userId, propertyId: $propertyId");
    final token = stockage?.read<String>(StockageKeys.tokenKey);
    if (token == null) {
      print("❌ [PropertyFavoriteCtrl] Token non disponible");
      throw Exception('Token non disponible');
    }

    const url = Endpoints.AddFavorite;
    print("🔗 [PropertyFavoriteCtrl] URL POST: $url");

    var data = {
      "userId": int.tryParse(userId),
      "propertyId": int.tryParse(propertyId),
    };

    // Vérifier que la conversion a réussi
    if (data['userId'] == null || data['propertyId'] == null) {
      print("❌ [PropertyFavoriteCtrl] IDs invalides - userId: ${data['userId']}, propertyId: ${data['propertyId']}");
      throw Exception('IDs invalides');
    }

    try {
      // Ajout local d'abord pour un feedback immédiat (optimistic update)
      // On va créer un favori temporaire qui sera remplacé par la vraie réponse API
      print("💾 [PropertyFavoriteCtrl] Préparation de l'ajout local...");

      final response = await postData(url, data, token: token);
      print("📡 [PropertyFavoriteCtrl] Réponse API: ${response.data}");
      print("📡 [PropertyFavoriteCtrl] Status: ${response.status}");

      if (response.status == true && response.data['favorite'] != null) {
        // Ajout local si l'API réussit
        dynamic favoriteData = response.data['favorite'];
        PropertyFavoriteModel newFavorite;

        if (favoriteData is List) {
           if (favoriteData.isEmpty) {
             throw Exception("Liste de favoris vide retournée par l'API");
           }
           newFavorite = PropertyFavoriteModel.fromJson(favoriteData.first);
        } else {
           newFavorite = PropertyFavoriteModel.fromJson(favoriteData);
        }
        await _dbHelper.insertOrUpdateFavorite(newFavorite, userId);
        print("💾 [PropertyFavoriteCtrl] Favori ajouté en base locale");
        
        // Éviter les doublons
        if (!propertyFavorites.any((fav) => 
          fav.property?.propertyId.toString() == propertyId)) {
          propertyFavorites.add(newFavorite);
          print("📋 [PropertyFavoriteCtrl] Favori ajouté à la liste en mémoire");
        } else {
          print("⚠️ [PropertyFavoriteCtrl] Favori déjà présent dans la liste, mise à jour");
          final index = propertyFavorites.indexWhere((fav) => 
            fav.property?.propertyId.toString() == propertyId);
          if (index != -1) {
            propertyFavorites[index] = newFavorite;
          }
        }
        
        notifyListeners();
        print("✅ [PropertyFavoriteCtrl] Favori ajouté avec succès");
        return true;
      } else if (response.data['message'] != null &&
          response.data['message'].toString().toLowerCase().contains('déjà')) {
        // Cas où le favori existe déjà - considérer comme succès
        print("ℹ️ [PropertyFavoriteCtrl] Favori déjà existant, considéré comme succès");
        // Synchroniser depuis l'API pour s'assurer qu'on a les bonnes données
        await getFavoritesByUser(userId);
        return true;
      } else {
        final errorMsg = response.data['message'] ?? 'Échec de l\'ajout aux favoris';
        print("❌ [PropertyFavoriteCtrl] Erreur API: $errorMsg");
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      print("❌ [PropertyFavoriteCtrl] Erreur lors de l'ajout: $e");
      print("📚 [PropertyFavoriteCtrl] Stack trace: $stackTrace");
      rethrow;
    }
  }

  Future<bool> removeFavorite(String userId, String propertyId) async {
    print("🗑️ [PropertyFavoriteCtrl] Début removeFavorite - userId: $userId, propertyId: $propertyId");
    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    if (tkn == null) {
      print("❌ [PropertyFavoriteCtrl] Token non disponible");
      throw Exception('Token non disponible');
    }

    // Utiliser le nouvel endpoint: /api/favorite/delete/{userId}/{propertyId}
    final url = "favorite/delete/$userId/$propertyId";
    print("🔗 [PropertyFavoriteCtrl] URL DELETE: $url");

    try {
      // Suppression locale d'abord pour un feedback immédiat
      final userIdInt = int.tryParse(userId);
      if (userIdInt != null) {
        final deletedCount = await _dbHelper.removeFavorite(userId, propertyId);
        print("💾 [PropertyFavoriteCtrl] Suppression locale: $deletedCount ligne(s) supprimée(s)");
      }

      // Suppression dans la liste en mémoire
      propertyFavorites.removeWhere((fav) =>
          fav.userId.toString() == userId &&
          fav.property?.propertyId.toString() == propertyId);
      print("📋 [PropertyFavoriteCtrl] Supprimé de la liste en mémoire");

      // Appel API
      final response = await deleteData(url, token: tkn);
      print("📡 [PropertyFavoriteCtrl] Réponse API: ${response.data}");
      print("📡 [PropertyFavoriteCtrl] Status: ${response.status}");

      // Vérifier plusieurs formats de réponse de succès
      final responseData = response.data;
      final message = responseData?['message']?.toString().toLowerCase() ?? '';
      final success = responseData?['success'] ?? false;
      
      if (response.status == true || 
          success == true || 
          message.contains('deleted') || 
          message.contains('successfully') || 
          message.contains('removed') ||
          message.contains('supprimé')) {
        print("✅ [PropertyFavoriteCtrl] Favori supprimé avec succès");
        notifyListeners();
        return true;
      } else {
        print("⚠️ [PropertyFavoriteCtrl] Réponse API ambiguë, mais considérée comme succès");
        // Même si la réponse n'est pas claire, on considère que c'est un succès car la suppression locale a réussi
        notifyListeners();
        return true;
      }
    } catch (e, stackTrace) {
      print("❌ [PropertyFavoriteCtrl] Erreur lors de la suppression: $e");
      print("📚 [PropertyFavoriteCtrl] Stack trace: $stackTrace");
      
      // En cas d'erreur API, on garde la suppression locale (optimistic update)
      // L'utilisateur verra que le favori est retiré, et la prochaine sync corrigera si nécessaire
      print("💾 [PropertyFavoriteCtrl] Conservation de la suppression locale malgré l'erreur API");
      notifyListeners();
      return true; // Retourner true car la suppression locale a réussi
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