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
          if (fav.property?.propertyId != null)
            fav.property!.propertyId.toString(): true
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
          if (fav.property?.propertyId != null)
            fav.property!.propertyId.toString(): true
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
    print("🔄 [FavoriteProvider] ========== DÉBUT toggleFavorite ==========");
    print("🔄 [FavoriteProvider] userId: $userId, propertyId: $propertyId");
    
    // Éviter les actions multiples simultanées sur la même propriété
    if (_state.isLoadingProperty(propertyId)) {
      print("⏸️ [FavoriteProvider] Action déjà en cours pour cette propriété, ignorée");
      return;
    }

    try {
      // Vérification plus robuste de l'userId
      if (userId.isEmpty) {
        print("❌ [FavoriteProvider] userId vide");
        throw Exception("ID utilisateur invalide ou non connecté");
      }

      // Vérification que userId peut être converti en int
      final userIdInt = int.tryParse(userId);
      if (userIdInt == null) {
        print("❌ [FavoriteProvider] Format d'userId invalide: $userId");
        throw Exception("Format d'ID utilisateur invalide");
      }

      // Marquer cette propriété comme en cours de chargement
      final updatedLoading = Set<String>.from(_state.loadingProperties)..add(propertyId);
      _state = _state.copyWith(loadingProperties: updatedLoading);
      notifyListeners();
      print("⏳ [FavoriteProvider] Propriété marquée comme en chargement");

      final isCurrentlyFavorite = _state.isFavorite(propertyId);
      final newStatus = !isCurrentlyFavorite;
      print("💭 [FavoriteProvider] État actuel: $isCurrentlyFavorite → Nouvel état: $newStatus");

      // Mise à jour optimiste immédiate pour un feedback instantané
      final updatedStatus = Map<String, bool>.from(_state.favoriteStatus);
      updatedStatus[propertyId] = newStatus;
      _state = _state.copyWith(favoriteStatus: updatedStatus);
      notifyListeners();
      print("✨ [FavoriteProvider] Mise à jour optimiste effectuée (UI mise à jour immédiatement)");

      // Appel API en arrière-plan
      try {
        if (newStatus) {
          print("➕ [FavoriteProvider] Ajout du favori...");
          final success = await _favoriteCtrl.addFavorite(userId, propertyId);
          if (!success) {
            throw Exception("Échec de l'ajout aux favoris");
          }
          print("✅ [FavoriteProvider] Favori ajouté avec succès via API");
          
          // Vérifier que le favori est bien dans la DB locale
          final favorites = await _dbHelper.getFavoritesByUser(userId);
          final isInDb = favorites.any((fav) => 
            fav.property?.propertyId.toString() == propertyId);
          
          print("💾 [FavoriteProvider] Favori dans DB locale: $isInDb");
          
          // Mettre à jour l'état : conserver l'état actuel et s'assurer que ce favori est à true
          final updatedStatus = Map<String, bool>.from(_state.favoriteStatus);
          updatedStatus[propertyId] = true; // Forcer à true car l'ajout a réussi
          
          // Ajouter aussi les autres favoris de la DB pour être sûr
          for (var fav in favorites) {
            if (fav.property?.propertyId != null) {
              updatedStatus[fav.property!.propertyId.toString()] = true;
            }
          }
          
          _state = _state.copyWith(favoriteStatus: updatedStatus);
          notifyListeners(); // Notifier immédiatement pour mettre à jour l'UI
          print("💾 [FavoriteProvider] État mis à jour - propertyId $propertyId est favori: ${updatedStatus[propertyId]}");
          print("💾 [FavoriteProvider] Total favoris dans l'état: ${updatedStatus.length}");
        } else {
          print("➖ [FavoriteProvider] Suppression du favori...");
          final success = await _favoriteCtrl.removeFavorite(userId, propertyId);
          if (!success) {
            throw Exception("Échec de la suppression");
          }
          print("✅ [FavoriteProvider] Favori supprimé avec succès via API");
          
          // Vérifier que le favori n'est plus dans la DB locale
          final favorites = await _dbHelper.getFavoritesByUser(userId);
          final isStillInDb = favorites.any((fav) => 
            fav.property?.propertyId.toString() == propertyId);
          
          print("💾 [FavoriteProvider] Favori encore dans DB locale: $isStillInDb");
          
          // Mettre à jour l'état : retirer ce favori et conserver les autres
          final updatedStatus = Map<String, bool>.from(_state.favoriteStatus);
          updatedStatus.remove(propertyId); // Retirer complètement de la map
          
          // Mettre à jour avec les favoris restants de la DB
          final statusFromDb = <String, bool>{
            for (var fav in favorites)
              if (fav.property?.propertyId != null)
                fav.property!.propertyId.toString(): true
          };
          updatedStatus.addAll(statusFromDb);
          
          _state = _state.copyWith(favoriteStatus: updatedStatus);
          notifyListeners(); // Notifier immédiatement pour mettre à jour l'UI
          print("✅ [FavoriteProvider] Favori supprimé - propertyId: $propertyId, état mis à jour");
          print("💾 [FavoriteProvider] Total favoris dans l'état: ${updatedStatus.length}");
        }
      } catch (apiError, stackTrace) {
        print("❌ [FavoriteProvider] ========== ERREUR API ==========");
        print("❌ [FavoriteProvider] Erreur: $apiError");
        print("📚 [FavoriteProvider] Stack trace: $stackTrace");
        
        // Rollback en cas d'erreur API
        final rollbackStatus = Map<String, bool>.from(_state.favoriteStatus);
        rollbackStatus[propertyId] = isCurrentlyFavorite;
        _state = _state.copyWith(favoriteStatus: rollbackStatus);
        print("↩️ [FavoriteProvider] Rollback effectué - retour à l'état précédent");
        notifyListeners();
        rethrow;
      }

      // Retirer de la liste des propriétés en chargement et notifier
      final finalLoading = Set<String>.from(_state.loadingProperties)..remove(propertyId);
      _state = _state.copyWith(loadingProperties: finalLoading);
      notifyListeners();
      print("✅ [FavoriteProvider] ========== FIN toggleFavorite (succès) ==========");
    } catch (e, stackTrace) {
      print("❌ [FavoriteProvider] ========== EXCEPTION dans toggleFavorite ==========");
      print("❌ [FavoriteProvider] Erreur: $e");
      print("📚 [FavoriteProvider] Stack trace: $stackTrace");
      
      // Retirer de la liste des propriétés en chargement même en cas d'erreur
      final errorLoading = Set<String>.from(_state.loadingProperties)..remove(propertyId);
      _state = _state.copyWith(
        loadingProperties: errorLoading,
        error: e.toString(),
      );
      notifyListeners();
      print("❌ [FavoriteProvider] ========== FIN toggleFavorite (erreur) ==========");
      rethrow;
    }
  }


}