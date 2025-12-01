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
    final token = stockage?.read<String>(StockageKeys.tokenKey);
    print("Token récupéré: $token");
    if (token == null) throw Exception('Token non disponible');

    const url = Endpoints.AddFavorite;
    loading = true;
    notifyListeners();

    var data = {
      "userId": int.tryParse(userId),
      "propertyId": int.tryParse(propertyId),
    };

    // Vérifier que la conversion a réussi
    if (data['userId'] == null || data['propertyId'] == null) {
      loading = false;
      notifyListeners();
      throw Exception('IDs invalides');
    }

    try {
      final response = await postData(url, data, token: token);
      print("Add favorite response: ${response.data}");

      if (response.data['favorite'] != null) {
        // Ajout local si l'API réussit
        final newFavorite = PropertyFavoriteModel.fromJson(response.data['favorite']);
        await _dbHelper.insertOrUpdateFavorite(newFavorite, userId);
        propertyFavorites.add(newFavorite);
        loading = false;
        notifyListeners();
        return true;
      } else if (response.data['message'] != null &&
          response.data['message'].contains('déjà dans vos favoris')) {
        // Cas où le favori existe déjà
        loading = false;
        notifyListeners();
        throw Exception(response.data['message']);
      } else {
        throw Exception(response.data['message'] ?? 'Échec de l\'ajout aux favoris');
      }
    } catch (e) {
      print("Error adding favorite: $e");
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeFavorite(String userId, String propertyId) async {
    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    if (tkn == null) throw Exception('Token non disponible');

    final url = "${Endpoints.removeMyfavorites}/$propertyId";

    loading = true;
    notifyListeners();

    try {
      final response = await deleteData(url, token: tkn);
      print("Remove favorite response: ${response.data}");

      if ((response.data['message']?.toString().toLowerCase().contains('deleted') == true ||
          response.data['message']?.toString().toLowerCase().contains('successfully') == true ||
          response.data['message']?.toString().toLowerCase().contains('removed') == true)) {

        // Suppression locale
        propertyFavorites.removeWhere((fav) =>
        fav.userId.toString() == userId &&
            fav.property?.propertyId.toString() == propertyId);

        // Supprimer de la base de données locale
        await _dbHelper.removeFavorite(userId, propertyId);

        loading = false;
        notifyListeners();
        return true;
      } else {
        throw Exception(response.data['message'] ?? 'Échec de la suppression');
      }
    } catch (e) {
      print("Error removing favorite: $e");
      loading = false;
      notifyListeners();
      return false;
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