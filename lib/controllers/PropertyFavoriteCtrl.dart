

import 'package:casa/models/PropertyFavoriteModel.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/database/FavoriteDatabaseHelper.dart';
import 'package:casa/utils/requetes.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_storage/get_storage.dart';

import '../utils/Endpoints.dart';

class PropertyFavoriteCtrl with ChangeNotifier{
  GetStorage? stockage;
  bool loading = false;

  List<PropertyFavoriteModel> propertyFavorites = [];
  final FavoriteDatabaseHelper _dbHelper = FavoriteDatabaseHelper.instance;

  PropertyFavoriteCtrl({this.stockage});

  Future<List<PropertyFavoriteModel>> getFavoritesByUser(String userId) async {
    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    final url = "${Endpoints.getMyfavorites}/$userId/favorites";

    loading = true;
    notifyListeners();

    try {
      final response = await getData(url, token: tkn);

      if (response != null && response['success'] == true) {
        await _dbHelper.clearUserFavorites(userId);

        List<PropertyFavoriteModel> favorites = [];

        if (response['data'] is List) {
          favorites = (response['data'] as List)
              .map<PropertyFavoriteModel>((e) => PropertyFavoriteModel.fromJson(e))
              .toList();
        } else if (response['data']['data'] is List) {
          favorites = (response['data']['data'] as List)
              .map<PropertyFavoriteModel>((e) => PropertyFavoriteModel.fromJson(e))
              .toList();
        }

        for (var fav in favorites) {
          await _dbHelper.insertOrUpdateFavorite(fav, userId);
        }

        propertyFavorites = favorites;
      }
    } catch (e) {
      print("Error fetching favorites: $e");
    }

    if (propertyFavorites.isEmpty) {
      propertyFavorites = await _dbHelper.getFavoritesByUser(userId);
    }

    loading = false;
    notifyListeners();
    return propertyFavorites;
  }

  Future<bool> addFavorite(String userId, String propertyId) async {
    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    if (tkn == null) throw Exception('Token non disponible');

    const url = Endpoints.AddFavorite;
    loading = true;
    notifyListeners();

    var data = {
      'UserId': userId,
      'PropertyId': propertyId,
    };

    try {
      final response = await postData(url,data,token: tkn,);

      if (response.data['success'] == true) {
        // Ajout local si l'API réussit
        final newFavorite = PropertyFavoriteModel.fromJson(response.data['data']);
        await _dbHelper.insertOrUpdateFavorite(newFavorite, userId);
        propertyFavorites.add(newFavorite);

        loading = false;
        notifyListeners();
        return true;
      } else if (response != null && response.data['message'] == 'Cette propriété est déjà dans vos favoris') {
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

    final url = Endpoints.removeMyfavorites;

    var data = {
      'UserId': userId,
      'PropertyId': propertyId,
    };

    try {
      final response = await postData(url, data, token: tkn);

      if (response.data['success'] == true) {
        // Vérifier que l'élément existe avant de le supprimer
        final index = propertyFavorites.indexWhere((fav) =>
        fav.userId.toString() == userId &&
            fav.property?.propertyId.toString() == propertyId);

        if (index != -1) {
          propertyFavorites.removeAt(index);
          notifyListeners();
        }
        return true;
      } else {
        throw Exception(response.data['message'] ?? 'Échec de la suppression');
      }
    } catch (e) {
      print("Error removing favorite: $e");
      return false;
    }
  }






}