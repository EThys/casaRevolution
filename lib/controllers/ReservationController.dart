import 'package:casa/utils/database/ReservationDatabaseHelper.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../models/ReservationModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/requetes.dart';

class ReservationController with ChangeNotifier {
  ReservationController({this.stockage});

  GetStorage? stockage;
  bool loading = false;
  List<ReservationModel> reservations = [];
  ReservationModel? currentReservation;

  // Récupérer l'ID de l'utilisateur connecté (userId)
  String? _getCurrentUserId() {
    final dynamic userData = stockage?.read(StockageKeys.userKey);
    final userId = userData?['user']?['userId'] ?? userData?['userId'];
    return userId?.toString();
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c');
  }

  bool _isSuccessMessage(String? message) {
    if (message == null) return false;
    final normalized = _normalize(message);
    return normalized.contains("a ete cree avec succes") ||
        normalized.contains("a ete creee avec succes") ||
        normalized.contains("a ete creer avec succes");
  }

  // Récupérer toutes les réservations de l'utilisateur connecté
  Future<List<ReservationModel>> getAllReservations() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      print("❌ Aucun user ID trouvé pour récupérer les réservations");
      return [];
    }

    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    final url = "${Endpoints.allReservations}";
    loading = true;
    notifyListeners();

    try {
      // Essayer de récupérer depuis le réseau
      var response = await getData(url, token: tkn);
      print("🌐 Requête réservations: ${url}");
      print("📡 Réponse des réservations: ${response}");

      // Vérifier si la requête a réussi en cherchant la clé "reservations" ou "data"
      if (response != null &&
          (response['reservation'] != null || response['data'] != null)) {

        // Déterminer quelle clé contient les données
        List<dynamic> reservationsData = response['reservation'] ?? response['data'];

        // Vérifier que la liste n'est pas vide
        if (reservationsData is List) {
          List<ReservationModel> allReservations = reservationsData
              .map<ReservationModel>((e) => ReservationModel.fromJson(e))
              .toList();

          // Filtrer pour ne garder que les réservations de l'utilisateur connecté
          List<ReservationModel> userReservations = allReservations
              .where((reservation) => reservation.user?.userId.toString() == userId)
              .toList();

          print("👤 Réservations filtrées pour user $userId: ${userReservations.length}");

          // Sauvegarder en local
          final db = ReservationDatabaseHelper.instance;
          await db.clearUserReservations(userId); // Vider avant de remplir
          for (var reservation in userReservations) {
            await db.insertOrUpdateReservation(reservation, userId);
          }

          this.reservations = userReservations;
          loading = false;
          notifyListeners();
          return userReservations;
        }
      }
    } catch (e) {
      print("❌ Erreur réseau: $e");
      // Continuer avec le cache si échec réseau
    }

    // Si échec réseau ou réponse invalide, charger depuis SQLite
    final db = ReservationDatabaseHelper.instance;
    final cachedReservations = await db.getReservationsByUser(userId);

    this.reservations = cachedReservations;
    loading = false;
    notifyListeners();
    return cachedReservations;
  }

  // Récupérer les réservations de l'utilisateur connecté
  Future<List<ReservationModel>> getMyReservations() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      print("❌ Aucun user ID trouvé dans le stockage");
      return [];
    }

    print("🔍 Récupération des réservations pour user: $userId");
    
    loading = true;
    notifyListeners();

    try {
      // Construction de l'URL spécifique: reservations/user/{userId}
      // Utilisation de Endpoints.reservations (reservations) et Endpoints.reservationsByUser (user)
      final url = "${Endpoints.reservations}/${Endpoints.reservationsByUser}/$userId";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      
      print("🌐 Requête mes réservations: $url");
      var response = await getData(url, token: tkn);

      if (response != null && (response['reservation'] != null || response['data'] != null)) {
        List<dynamic> reservationsData = response['reservation'] ?? response['data'];
        
        print("📋 [ReservationController] Nombre d'éléments dans reservation: ${reservationsData.length}");

        if (reservationsData is List && reservationsData.isNotEmpty) {
          List<ReservationModel> userReservations = [];
          
          for (var item in reservationsData) {
            try {
              // Vérifier la structure de l'élément et caster en Map<String, dynamic>
              if (item is Map) {
                final itemMap = Map<String, dynamic>.from(item);
                print("📋 [ReservationController] Structure item: ${itemMap.keys.toList()}");
                
                final reservationData = itemMap['reservation'] as Map<String, dynamic>?;
                final itemUserId = reservationData?['userId']?.toString();
                
                print("📋 [ReservationController] userId dans réservation: $itemUserId, userId recherché: $userId");
                
                // On accepte la réservation même si userId est null (car l'endpoint API filtre déjà par user)
                // On ne loggue un warning que si userId est présent ET différent
                if (itemUserId != null && itemUserId != userId) {
                  print("⚠️ [ReservationController] Warning: userId $itemUserId != $userId (mais ajouté car retourné par l'API)");
                }
                
                final reservation = ReservationModel.fromJson(itemMap);
                userReservations.add(reservation);
              }
            } catch (e, stack) {
              print("❌ [ReservationController] Erreur parsing réservation: $e");
              print("🔍 Stack: $stack");
            }
          }

          print("👤 Mes réservations récupérées: ${userReservations.length}");

          // Sauvegarder en local
          final db = ReservationDatabaseHelper.instance;
          await db.clearUserReservations(userId); // Vider avant de remplir
          for (var reservation in userReservations) {
            await db.insertOrUpdateReservation(reservation, userId);
          }

          this.reservations = userReservations;
          loading = false;
          notifyListeners();
          return userReservations;
        }
      } else {
         print("⚠️ Aucune réservation trouvée ou format réponse invalide");
      }
    } catch (e) {
      print("❌ Erreur réseau mes réservations: $e");
    }

    // Fallback vers le cache local
    final db = ReservationDatabaseHelper.instance;
    final cachedReservations = await db.getReservationsByUser(userId);

    this.reservations = cachedReservations;
    loading = false;
    notifyListeners();
    return cachedReservations;
  }

  // Récupérer les réservations par statut pour l'utilisateur connecté
  Future<List<ReservationModel>> getReservationsByStatus(String status) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      return [];
    }

    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.reservations}/${Endpoints.reservationsByUser}/$userId?status=$status";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      var response = await getData(url, token: tkn);

      if (response != null && (response['reservation'] != null || response['data'] != null)) {
        List<dynamic> reservationsData = response['reservation'] ?? response['data'];

        if (reservationsData is List) {
          List<ReservationModel> filteredReservations = reservationsData
              .map<ReservationModel>((e) => ReservationModel.fromJson(e))
              .where((reservation) => reservation.status == status)
              .toList();

          // Sauvegarder en local (ne pas vider tout car c'est filtré par statut, 
          // mais on pourrait vider par statut si nécessaire. Pour l'instant on garde la logique d'insertOrUpdate)
          final db = ReservationDatabaseHelper.instance;
          for (var reservation in filteredReservations) {
            await db.insertOrUpdateReservation(reservation, userId);
          }

          loading = false;
          notifyListeners();
          return filteredReservations;
        }
      }
    } catch (e) {
      print("❌ Erreur réseau pour réservations par statut: $e");
    }

    // Fallback vers le cache local
    final db = ReservationDatabaseHelper.instance;
    final cachedReservations = await db.getReservationsByStatus(userId, status);

    loading = false;
    notifyListeners();
    return cachedReservations;
  }

  Future<ReservationModel?> getReservationById(int reservationId) async {
    final userId = _getCurrentUserId();
    loading = true;
    notifyListeners();

    try {
      var url = "${Endpoints.reservations}/$reservationId";
      var response = await getData(url);

      // Vérifier si la requête a réussi
      if (response != null && response['data'] != null) {
        ReservationModel reservation = ReservationModel.fromJson(response['data']);

        // Vérifier que la réservation appartient à l'utilisateur connecté
        if (reservation.user?.userId.toString() != userId) {
          print("⛔ Réservation $reservationId n'appartient pas à l'utilisateur $userId");
          loading = false;
          notifyListeners();
          return null;
        }

        currentReservation = reservation;

        // Sauvegarder en local
        final db = ReservationDatabaseHelper.instance;
        await db.insertOrUpdateReservation(reservation, userId!);

        loading = false;
        notifyListeners();
        return reservation;
      } else {
        print("Aucune donnée reçue pour la réservation $reservationId");
      }
    } catch (e) {
      print("Erreur lors de la récupération de la réservation $reservationId : $e");
    }

    // Fallback vers le cache local
    final db = ReservationDatabaseHelper.instance;
    final reservation = await db.getReservationById(reservationId.toString());

    // Vérifier l'appartenance dans le cache aussi
    if (reservation != null && reservation.user?.userId.toString() != userId) {
      print("⛔ Réservation cachée $reservationId n'appartient pas à l'utilisateur $userId");
      loading = false;
      notifyListeners();
      return null;
    }

    loading = false;
    notifyListeners();
    return reservation;
  }

  Future<HttpResponse> createReservation(
    Map<String, dynamic> reservationData, {
    int? propertyOwnerId,
  }) async {
    try {
      loading = true;
      notifyListeners();

      // Vérification locale avant l'appel réseau
      final userId = _getCurrentUserId();
      if (userId != null) {
        // Empêcher la réservation de son propre bien
        if (propertyOwnerId != null &&
            propertyOwnerId.toString() == userId) {
          loading = false;
          notifyListeners();
          const errorMsg = "You can't reserve your own property";
          return HttpResponse(
            status: false,
            data: {'error': errorMsg},
            errorMsg: errorMsg,
          );
        }

        // Empêcher la duplication d'une réservation en attente pour le même bien
        final propertyId = reservationData['propertyId']?.toString();
        final hasPending = reservations.any(
          (r) =>
              r.user?.userId?.toString() == userId &&
              r.property?.propertyId?.toString() == propertyId &&
              (r.status?.toUpperCase() == 'PENDING'),
        );

        if (hasPending) {
          loading = false;
          notifyListeners();
          const errorMsg =
              "You already have a pending reservation with this property";
          return HttpResponse(
            status: false,
            data: {'error': errorMsg},
            errorMsg: errorMsg,
          );
        }
      }

      final url = Endpoints.addReservations;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      print("URL: $url");
      print("TOKEN: $tkn");

      HttpResponse response = await postData(url, reservationData, token: tkn);
      print("REPONSE: ${response.data}");

      final rawMessage = response.data?['message'] ?? response.data?['msg'];
      final isSuccess = _isSuccessMessage(rawMessage?.toString());

      // Gérer explicitement les erreurs renvoyées par l'API, même si status HTTP est true
      final apiError = response.data?['error'] ?? (isSuccess ? null : response.data?['message']);
      if (apiError != null && !isSuccess) {
        loading = false;
        notifyListeners();
        return HttpResponse(
          status: false,
          data: response.data,
          errorMsg: apiError.toString(),
        );
      }

      // Si le message indique le succès, force le statut à true
      if (isSuccess) {
        response.status = true;
      }

      // Vérifier si la création a réussi
      if (response.status == true && response.data != null) {
        // Déterminer quelle clé contient la réservation créée
        dynamic reservationJson = response.data['reservation'] ?? response.data['data'];

        if (reservationJson != null) {
          final newReservation = ReservationModel.fromJson(reservationJson);
          reservations.add(newReservation);

          // Sauvegarder en local
          final db = ReservationDatabaseHelper.instance;
          final userId = _getCurrentUserId();
          if (userId != null) {
            await db.insertOrUpdateReservation(newReservation, userId);
          }

          notifyListeners();
          print("✅ Réservation créée avec ID: ${newReservation.reservationId}");
        }
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      print("❌ Erreur création réservation: $e");
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Failed to create reservation: $e",
        isException: true,
      );
    }
  }

  Future<HttpResponse> updateReservationStatus(int reservationId, String status) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.reservations}/$reservationId/status";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      Map<String, dynamic> updateData = {
        'status': status,
      };

      HttpResponse response = await patchData(url, updateData, token: tkn);

      // Vérifier si la mise à jour a réussi
      if (response.status == true) {
        // Mettre à jour en base locale
        final db = ReservationDatabaseHelper.instance;
        final normalizedStatus = status.toUpperCase();
        await db.updateReservationStatus(reservationId.toString(), normalizedStatus);

        // Mettre à jour localement avec le statut normalisé
        final index = reservations.indexWhere((r) => r.reservationId == reservationId);
        if (index != -1) {
          reservations[index].status = normalizedStatus;
        }
        if (currentReservation?.reservationId == reservationId) {
          currentReservation?.status = normalizedStatus;
        }

        notifyListeners();
        print("✅ Statut réservation $reservationId mis à jour: $status");
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      print("❌ Erreur mise à jour statut: $e");
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Failed to update reservation status: $e",
        isException: true,
      );
    }
  }

  Future<HttpResponse> cancelReservation(int reservationId, String reason) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.reservations}/delete/$reservationId";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      Map<String, dynamic> cancelData = {
        'cancellationReason': reason,
      };

      HttpResponse response = await deleteData(url, data: cancelData, token: tkn);

      if (response.status == true) {
        // Mettre à jour localement
        final index = reservations.indexWhere((r) => r.reservationId == reservationId);
        if (index != -1) {
          reservations[index].status = 'CANCELLED';
          reservations[index].cancellationReason = reason;
        }

        // Mettre à jour en base locale
        final db = ReservationDatabaseHelper.instance;
        await db.updateReservationStatus(reservationId.toString(), 'CANCELLED');

        notifyListeners();
        print("✅ Réservation $reservationId annulée");
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      print("❌ Erreur annulation réservation: $e");
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Failed to cancel reservation: $e",
        isException: true,
      );
    }
  }

  // Récupérer le nombre de réservations par statut pour l'utilisateur connecté
  Future<Map<String, int>> getMyReservationCounts() async {
    final userId = _getCurrentUserId();
    if (userId == null) return {};

    // Utiliser les réservations déjà chargées en mémoire pour l'utilisateur connecté
    final userReservations = reservations.where((reservation) =>
    reservation.user?.userId.toString() == userId
    ).toList();

    // Compter par statut (normalisé en majuscules)
    final pendingCount = userReservations.where((r) => r.status?.toUpperCase() == 'PENDING').length;
    final confirmedCount = userReservations.where((r) => r.status?.toUpperCase() == 'CONFIRMED').length;
    final cancelledCount = userReservations.where((r) => r.status?.toUpperCase() == 'CANCELLED').length;
    final completedCount = userReservations.where((r) => r.status?.toUpperCase() == 'COMPLETED').length;

    print("📊 Compteurs réservations user $userId: PENDING=$pendingCount, CONFIRMED=$confirmedCount, CANCELLED=$cancelledCount, COMPLETED=$completedCount");

    return {
      'all': userReservations.length,
      'pending': pendingCount,
      'confirmed': confirmedCount,
      'cancelled': cancelledCount,
      'completed': completedCount,
    };
  }

  // Récupérer uniquement les réservations à venir de l'utilisateur
  Future<List<ReservationModel>> getMyUpcomingReservations() async {
    final userId = _getCurrentUserId();
    if (userId == null) return [];

    final db = ReservationDatabaseHelper.instance;
    return await db.getUpcomingReservations(userId);
  }

  // Récupérer les réservations reçues en tant qu'hôte (sur mes propriétés)
  Future<List<ReservationModel>> getHostReservations() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      print("❌ Aucun user ID trouvé pour récupérer les réservations hôte");
      return [];
    }

    print("🔍 Récupération des réservations hôte pour user: $userId");
    
    loading = true;
    notifyListeners();

    try {
      // Construction de l'URL: reservations/user/host/{userId}
      final url = "${Endpoints.reservations}/${Endpoints.reservationsByUser}/host/$userId";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      
      print("🌐 Requête réservations hôte: $url");
      var response = await getData(url, token: tkn);

      if (response != null && (response['reservations'] != null || response['data'] != null)) {
        List<dynamic> reservationsData = response['reservations'] ?? response['data'];
        
        print("📋 [ReservationController] Nombre de réservations hôte: ${reservationsData.length}");

        if (reservationsData is List && reservationsData.isNotEmpty) {
          List<ReservationModel> hostReservations = [];
          
          for (var item in reservationsData) {
            try {
              if (item is Map) {
                final itemMap = Map<String, dynamic>.from(item);
                final reservation = ReservationModel.fromJson(itemMap);
                hostReservations.add(reservation);
              }
            } catch (e, stack) {
              print("❌ [ReservationController] Erreur parsing réservation hôte: $e");
              print("🔍 Stack: $stack");
            }
          }

          print("👤 Réservations hôte récupérées: ${hostReservations.length}");
          
          loading = false;
          notifyListeners();
          return hostReservations;
        }
      } else {
         print("⚠️ Aucune réservation hôte trouvée ou format réponse invalide");
      }
    } catch (e) {
      print("❌ Erreur réseau réservations hôte: $e");
    }

    loading = false;
    notifyListeners();
    return [];
  }

  // Vider le cache local des réservations de l'utilisateur
  Future<void> clearMyReservations() async {
    final db = ReservationDatabaseHelper.instance;
    final userId = _getCurrentUserId();

    if (userId != null) {
      await db.clearUserReservations(userId);
    }

    reservations.clear();
    notifyListeners();
    print("🗑️ Cache réservations vidé pour user: $userId");
  }
}