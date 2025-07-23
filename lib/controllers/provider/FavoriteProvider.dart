import 'package:casa/controllers/PropertyFavoriteCtrl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/state/FavoriteState.dart';
import '../../utils/database/FavoriteDatabaseHelper.dart';

class FavoriteProvider with ChangeNotifier {
  final FavoriteDatabaseHelper _dbHelper;
  final PropertyFavoriteCtrl _favoriteCtrl;
  FavoriteState _state = FavoriteState(favoriteStatus: {});

  FavoriteProvider(this._dbHelper, this._favoriteCtrl);

  FavoriteState get state => _state;

  Future<void> initialize(String userId) async {
    try {
      _state = _state.copyWith(isLoading: true);
      notifyListeners();

      await _favoriteCtrl.getFavoritesByUser(userId);

      final favorites = await _dbHelper.getFavoritesByUser(userId);
      final statusMap = <String, bool>{
        for (var fav in favorites)
          if (fav.property?.PropertyId != null)
            fav.property!.PropertyId.toString(): true
      };

      _state = _state.copyWith(
        favoriteStatus: statusMap,
        isLoading: false,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      notifyListeners();
    }
  }

  // Dans FavoriteProvider
  Future<void> syncFavorites(String userId) async {
    try {
      _state = _state.copyWith(isLoading: true);
      notifyListeners();

      await _favoriteCtrl.getFavoritesByUser(userId);

      final favorites = await _dbHelper.getFavoritesByUser(userId);
      final statusMap = <String, bool>{
        for (var fav in favorites)
          if (fav.property?.PropertyId != null)
            fav.property!.PropertyId.toString(): true
      };

      _state = _state.copyWith(
        favoriteStatus: statusMap,
        isLoading: false,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      notifyListeners();
    }
  }

  Future<void> toggleFavorite({
    required String userId,
    required String propertyId,
  }) async {
    try {
      // Vérification plus robuste de l'userId
      if (userId.isEmpty) {
        throw Exception("ID utilisateur invalide ou non connecté");
      }

      // Vérification que userId peut être converti en int
      final userIdInt = int.tryParse(userId);
      if (userIdInt == null) {
        throw Exception("Format d'ID utilisateur invalide");
      }

      _state = _state.copyWith(isLoading: true);
      notifyListeners();

      final isCurrentlyFavorite = _state.isFavorite(propertyId);
      final newStatus = !isCurrentlyFavorite;

      // Mise à jour optimiste
      final updatedStatus = Map<String, bool>.from(_state.favoriteStatus);
      updatedStatus[propertyId] = newStatus;
      _state = _state.copyWith(favoriteStatus: updatedStatus);
      notifyListeners();

      // Appel API
      if (newStatus) {
        await _favoriteCtrl.addFavorite(userId, propertyId);
        await _favoriteCtrl.getFavoritesByUser(userId);
      } else {
        await _favoriteCtrl.removeFavorite(userId, propertyId);
        await _dbHelper.deleteFavorite(userIdInt, propertyId);
      }

      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    } catch (e) {
      // Rollback plus robuste
      final updatedStatus = Map<String, bool>.from(_state.favoriteStatus);
      updatedStatus[propertyId] = _state.favoriteStatus[propertyId] ?? false;
      _state = _state.copyWith(
        favoriteStatus: updatedStatus,
        error: e.toString(),
        isLoading: false,
      );
      notifyListeners();
      rethrow;
    }
  }


}