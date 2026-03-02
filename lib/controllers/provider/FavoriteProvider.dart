import 'package:casa/services/ConnectivityService.dart';
import 'package:casa/controllers/PropertyFavoriteCtrl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/state/FavoriteState.dart';
import '../../utils/database/FavoriteDatabaseHelper.dart';

class FavoriteProvider with ChangeNotifier {
  final FavoriteDatabaseHelper _dbHelper;
  final PropertyFavoriteCtrl _favoriteCtrl;
  FavoriteState _state = FavoriteState(favoriteStatus: {});
  final ConnectivityService _connectivityService = ConnectivityService();

  static String generateKey(String id, {int? typeId, bool isPrestation = false}) {
    if (isPrestation) return "S_$id";
    // Si c'est une propriété, on inclut le typeId (1 par défaut pour FLAT/MAISON)
    final tid = typeId ?? 1;
    return "P_${tid}_$id";
  }

  FavoriteProvider(this._dbHelper, this._favoriteCtrl);

  FavoriteState get state => _state;

  Future<void> initialize(String userId) async {
    try {
      _state = _state.copyWith(isLoading: true);
      notifyListeners();

      // Initialize connectivity listener
      _connectivityService.initialize();
      _connectivityService.connectionChange.listen((hasConnection) {
        if (hasConnection) {
          print("📡 [FavoriteProvider] Connexion rétablie : Lancement sync queue...");
          _favoriteCtrl.syncOfflineQueue(userId);
        }
      });

      // D'abord on essaie de synchroniser la queue
      _favoriteCtrl.syncOfflineQueue(userId).then((_) {
         print("🔄 [FavoriteProvider] Sync queue terminer en background");
      }).catchError((e) {
         print("⚠️ [FavoriteProvider] Sync queue failed (offline?): $e");
      });

      // Charger les favoris depuis API (ou cache si offline)
      await _favoriteCtrl.getFavoritesByUser(userId);

      // Récupérer les favoris stockés en local
      final favorites = await _dbHelper.getFavoritesByUser(userId);
      
      // Récupérer aussi la file d'attente pour appliquer les changements en attente
      final queue = await _dbHelper.getQueue(userId);

      final statusMap = <String, bool>{};
      for (var fav in favorites) {
        if (fav.prestation != null) {
          statusMap["S_${fav.prestation!.id}"] = true;
        } else if (fav.property != null) {
          final tid = fav.property!.propertyTypeId ?? 1;
          statusMap["P_${tid}_${fav.property!.propertyId}"] = true;
        }
      }
      
      // Appliquer les changements en attente par dessus
      for (var item in queue) {
         final pid = item['propertyId'] as String;
         final action = item['action'] as String;
         final tid = item['propertyTypeId'] as int?;
         final key = generateKey(pid, typeId: tid); // isPrestation non stocké en queue mais patterns propertyTypeId=12 utilisé avant
         
         if (action == 'ADD') {
           statusMap[key] = true;
         } else if (action == 'REMOVE') {
           statusMap.remove(key);
         }
      }

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
      final queue = await _dbHelper.getQueue(userId);

      final statusMap = <String, bool>{};
      for (var fav in favorites) {
        if (fav.prestation != null) {
          statusMap["S_${fav.prestation!.id}"] = true;
        } else if (fav.property != null) {
          final tid = fav.property!.propertyTypeId ?? 1;
          statusMap["P_${tid}_${fav.property!.propertyId}"] = true;
        }
      }
      
      // Apply pending queue items
      for (var item in queue) {
         final pid = item['propertyId'] as String;
         final action = item['action'] as String;
         final tid = item['propertyTypeId'] as int?;
         final key = generateKey(pid, typeId: tid);
         
         if (action == 'ADD') {
           statusMap[key] = true;
         } else if (action == 'REMOVE') {
           statusMap.remove(key);
         }
      }

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
    int? propertyTypeId,
    bool isPrestation = false,
  }) async {
    print("🔄 [FavoriteProvider] ========== DÉBUT toggleFavorite ==========");
    final key = generateKey(propertyId, typeId: propertyTypeId, isPrestation: isPrestation);
    print("🔄 [FavoriteProvider] userId: $userId, key: $key, type: $propertyTypeId");
    
    // Éviter les actions multiples simultanées sur la même propriété
    if (_state.loadingProperties.contains(key)) {
      print("⏸️ [FavoriteProvider] Action déjà en cours pour cette clé $key, ignorée");
      return;
    }

    try {
      if (userId.isEmpty) throw Exception("ID utilisateur invalide");

      // Marquer comme en cours de chargement
      final updatedLoading = Set<String>.from(_state.loadingProperties)..add(key);
      _state = _state.copyWith(loadingProperties: updatedLoading);
      notifyListeners();

      final isCurrentlyFavorite = _state.favoriteStatus[key] ?? false;
      final newStatus = !isCurrentlyFavorite;

      // Mise à jour optimiste
      final updatedStatus = Map<String, bool>.from(_state.favoriteStatus);
      if (newStatus) {
        updatedStatus[key] = true;
      } else {
        updatedStatus.remove(key);
      }
      _state = _state.copyWith(favoriteStatus: updatedStatus);
      notifyListeners();

      try {
        if (newStatus) {
          final success = await _favoriteCtrl.addFavorite(userId, propertyId, propertyTypeId: propertyTypeId, isPrestation: isPrestation);
          if (!success) throw Exception("Échec de l'ajout");
        } else {
          final success = await _favoriteCtrl.removeFavorite(userId, propertyId, propertyTypeId: propertyTypeId, isPrestation: isPrestation);
          if (!success) throw Exception("Échec de la suppression");
        }
      } catch (apiError) {
        // Rollback
        final rollbackStatus = Map<String, bool>.from(_state.favoriteStatus);
        if (isCurrentlyFavorite) {
          rollbackStatus[key] = true;
        } else {
          rollbackStatus.remove(key);
        }
        _state = _state.copyWith(favoriteStatus: rollbackStatus);
        notifyListeners();
        rethrow;
      }

      // Fin chargement
      final finalLoading = Set<String>.from(_state.loadingProperties)..remove(key);
      _state = _state.copyWith(loadingProperties: finalLoading);
      notifyListeners();
    } catch (e) {
      final errorLoading = Set<String>.from(_state.loadingProperties)..remove(key);
      _state = _state.copyWith(loadingProperties: errorLoading, error: e.toString());
      notifyListeners();
      rethrow;
    }
  }


}