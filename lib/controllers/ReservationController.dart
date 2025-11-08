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

  // Récupérer toutes les réservations de l'utilisateur connecté
  Future<List<ReservationModel>> getAllReservations() async {
    final url = "${Endpoints.allReservations}";
    loading = true;
    notifyListeners();

    try {
      // Essayer de récupérer depuis le réseau
      var response = await getData(url);

      print("Réponse des réservations: ${response}");

      // Vérifier si la requête a réussi en cherchant la clé "reservations" ou "data"
      if (response != null &&
          (response['reservations'] != null || response['data'] != null)) {

        // Déterminer quelle clé contient les données
        List<dynamic> reservationsData = response['reservations'] ?? response['data'];

        // Vérifier que la liste n'est pas vide
        if (reservationsData is List && reservationsData.isNotEmpty) {
          List<ReservationModel> reservations = reservationsData
              .map<ReservationModel>((e) => ReservationModel.fromJson(e))
              .toList();

          // Sauvegarder en local
          final db = ReservationDatabaseHelper.instance;
          final dynamic userData = stockage?.read(StockageKeys.userKey);
          final userId = userData?['userId']?.toString() ?? 'default_user';

          for (var reservation in reservations) {
            await db.insertOrUpdateReservation(reservation, userId);
          }

          this.reservations = reservations;
          loading = false;
          notifyListeners();
          return reservations;
        }
      }
    } catch (e) {
      print("Erreur réseau: $e");
      // Continuer avec le cache si échec réseau
    }

    // Si échec réseau ou réponse invalide, charger depuis SQLite
    final db = ReservationDatabaseHelper.instance;
    final dynamic userData = stockage?.read(StockageKeys.userKey);
    final userId = userData?['userId']?.toString() ?? 'default_user';

    final cachedReservations = await db.getReservationsByUser(userId);

    this.reservations = cachedReservations;
    loading = false;
    notifyListeners();
    return cachedReservations;
  }

  // Récupérer les réservations par ID utilisateur
  Future<List<ReservationModel>> getReservationsByUserId(int userId) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.reservationsByUser}/$userId";
      var response = await getData(url);

      print("📡 Réservations pour user $userId: $response");

      if (response != null && (response['reservations'] != null || response['data'] != null)) {
        List<dynamic> reservationsData = response['reservations'] ?? response['data'];

        if (reservationsData is List && reservationsData.isNotEmpty) {
          List<ReservationModel> userReservations = reservationsData
              .map<ReservationModel>((e) => ReservationModel.fromJson(e))
              .toList();

          // Sauvegarder en local
          final db = ReservationDatabaseHelper.instance;
          final currentUserId = userId.toString();

          for (var reservation in userReservations) {
            await db.insertOrUpdateReservation(reservation, currentUserId);
          }

          // Filtrer pour ne garder que celles de l'utilisateur courant
          this.reservations = userReservations.where((r) => r.user?.userId == userId).toList();

          loading = false;
          notifyListeners();
          return this.reservations;
        }
      }
    } catch (e) {
      print("❌ Erreur réseau pour réservations par user $userId: $e");
    }

    // Fallback vers le cache local
    final db = ReservationDatabaseHelper.instance;
    final cachedReservations = await db.getReservationsByUser(userId.toString());

    this.reservations = cachedReservations;
    loading = false;
    notifyListeners();
    return cachedReservations;
  }

  // Récupérer les réservations de l'utilisateur connecté
  Future<List<ReservationModel>> getMyReservations() async {
    final dynamic userData = stockage?.read(StockageKeys.userKey);
    final userId = userData?['userId'];

    if (userId == null) {
      print("❌ Aucun user ID trouvé dans le stockage");
      return [];
    }

    print("🔍 Récupération des réservations pour user: $userId");
    return await getReservationsByUserId(userId);
  }

  // Récupérer les réservations par statut pour l'utilisateur connecté
  Future<List<ReservationModel>> getReservationsByStatus(String status) async {
    loading = true;
    notifyListeners();

    try {
      final dynamic userData = stockage?.read(StockageKeys.userKey);
      final userId = userData?['userId'];

      if (userId == null) {
        loading = false;
        notifyListeners();
        return [];
      }

      final url = "${Endpoints.reservationsByUser}/$userId?status=$status";
      var response = await getData(url);

      if (response != null && (response['reservations'] != null || response['data'] != null)) {
        List<dynamic> reservationsData = response['reservations'] ?? response['data'];

        if (reservationsData is List && reservationsData.isNotEmpty) {
          List<ReservationModel> filteredReservations = reservationsData
              .map<ReservationModel>((e) => ReservationModel.fromJson(e))
              .where((reservation) => reservation.status == status) // Filtre supplémentaire
              .toList();

          // Sauvegarder en local
          final db = ReservationDatabaseHelper.instance;
          for (var reservation in filteredReservations) {
            await db.insertOrUpdateReservation(reservation, userId.toString());
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
    final dynamic userData = stockage?.read(StockageKeys.userKey);
    final userId = userData?['userId']?.toString() ?? 'default_user';

    final cachedReservations = await db.getReservationsByStatus(userId, status);

    loading = false;
    notifyListeners();
    return cachedReservations;
  }

  Future<ReservationModel?> getReservationById(int reservationId) async {
    loading = true;
    notifyListeners();

    try {
      var url = "${Endpoints.reservations}/$reservationId";
      var response = await getData(url);

      // Vérifier si la requête a réussi
      if (response != null && response['data'] != null) {
        ReservationModel reservation = ReservationModel.fromJson(response['data']);
        currentReservation = reservation;

        // Sauvegarder en local
        final db = ReservationDatabaseHelper.instance;
        final dynamic userData = stockage?.read(StockageKeys.userKey);
        final userId = userData?['userId']?.toString() ?? 'default_user';

        await db.insertOrUpdateReservation(reservation, userId);

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

    loading = false;
    notifyListeners();
    return reservation;
  }

  Future<HttpResponse> createReservation(Map<String, dynamic> reservationData) async {
    try {
      loading = true;
      notifyListeners();

      final url = Endpoints.addReservations;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      print("URL: $url");
      print("TOKEN: $tkn");

      HttpResponse response = await postData(url, reservationData, token: tkn);
      print("REPONSE: ${response.data}");

      // Vérifier si la création a réussi
      if (response.status == true && response.data != null) {
        // Déterminer quelle clé contient la réservation créée
        dynamic reservationJson = response.data['reservation'] ?? response.data['data'];

        if (reservationJson != null) {
          final newReservation = ReservationModel.fromJson(reservationJson);
          reservations.add(newReservation);

          // Sauvegarder en local
          final db = ReservationDatabaseHelper.instance;
          final dynamic userData = stockage?.read(StockageKeys.userKey);
          final userId = userData?['userId']?.toString() ?? 'default_user';

          await db.insertOrUpdateReservation(newReservation, userId);

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
        // Mettre à jour localement
        final index = reservations.indexWhere((r) => r.reservationId == reservationId);
        if (index != -1) {
          reservations[index].status = status;
        }
        if (currentReservation?.reservationId == reservationId) {
          currentReservation?.status = status;
        }

        // Mettre à jour en base locale
        final db = ReservationDatabaseHelper.instance;
        await db.updateReservationStatus(reservationId.toString(), status);

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

      final url = "${Endpoints.reservations}/$reservationId/cancel";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      Map<String, dynamic> cancelData = {
        'cancellationReason': reason,
      };

      HttpResponse response = await postData(url, cancelData, token: tkn);

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
    final dynamic userData = stockage?.read(StockageKeys.userKey);
    final userId = userData?['userId']?.toString();

    if (userId == null) return {};

    final db = ReservationDatabaseHelper.instance;

    final all = await db.getReservationsByUser(userId);
    final pending = await db.getReservationsByStatus(userId, 'PENDING');
    final confirmed = await db.getReservationsByStatus(userId, 'CONFIRMED');
    final cancelled = await db.getReservationsByStatus(userId, 'CANCELLED');

    return {
      'all': all.length,
      'pending': pending.length,
      'confirmed': confirmed.length,
      'cancelled': cancelled.length,
    };
  }

  // Récupérer uniquement les réservations à venir de l'utilisateur
  Future<List<ReservationModel>> getMyUpcomingReservations() async {
    final dynamic userData = stockage?.read(StockageKeys.userKey);
    final userId = userData?['userId']?.toString();

    if (userId == null) return [];

    final db = ReservationDatabaseHelper.instance;
    return await db.getUpcomingReservations(userId);
  }

  // Vider le cache local des réservations de l'utilisateur
  Future<void> clearMyReservations() async {
    final db = ReservationDatabaseHelper.instance;
    final dynamic userData = stockage?.read(StockageKeys.userKey);
    final userId = userData?['userId']?.toString();

    if (userId != null) {
      await db.clearUserReservations(userId);
    }

    reservations.clear();
    notifyListeners();
    print("🗑️ Cache réservations vidé pour user: $userId");
  }
}