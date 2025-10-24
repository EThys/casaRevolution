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
          (response['reservation'] != null || response['data'] != null)) {

        // Déterminer quelle clé contient les données
        List<dynamic> reservationsData = response['reservations'] ?? response['data'];

        // Vérifier que la liste n'est pas vide
        if (reservationsData is List && reservationsData.isNotEmpty) {
          List<ReservationModel> reservations = reservationsData
              .map<ReservationModel>((e) => ReservationModel.fromJson(e))
              .toList();

          // Sauvegarder en local
          final db = ReservationDatabaseHelper.instance;
          final userId = stockage?.read<String>(StockageKeys.userKey) ?? 'default_user';

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
    final userId = stockage?.read<String>(StockageKeys.userKey)?? 'default_user';
    final cachedReservations = await db.getReservationsByUser(userId);

    this.reservations = cachedReservations;
    loading = false;
    notifyListeners();
    return cachedReservations;
  }

  // Future<List<ReservationModel>> getReservationsByStatus(String status) async {
  //   loading = true;
  //   notifyListeners();
  //
  //   try {
  //     final url = "${Endpoints.reservations}?status=$status";
  //     var response = await getData(url);
  //
  //     if (response != null && (response['reservations'] != null || response['data'] != null)) {
  //       List<dynamic> reservationsData = response['reservations'] ?? response['data'];
  //
  //       if (reservationsData is List && reservationsData.isNotEmpty) {
  //         List<ReservationModel> filteredReservations = reservationsData
  //             .map<ReservationModel>((e) => ReservationModel.fromJson(e))
  //             .toList();
  //
  //         // Sauvegarder en local
  //         final db = ReservationDatabaseHelper.instance;
  //         final userId = stockage?.read<String>(StockageKeys.userId) ?? 'default_user';
  //
  //         for (var reservation in filteredReservations) {
  //           await db.insertOrUpdateReservation(reservation, userId);
  //         }
  //
  //         loading = false;
  //         notifyListeners();
  //         return filteredReservations;
  //       }
  //     }
  //   } catch (e) {
  //     print("Erreur réseau pour réservations par statut: $e");
  //   }
  //
  //   // Fallback vers le cache local
  //   final db = ReservationDatabaseHelper.instance;
  //   final userId = stockage?.read<String>(StockageKeys.userId) ?? 'default_user';
  //   final cachedReservations = await db.getReservationsByStatus(userId, status);
  //
  //   loading = false;
  //   notifyListeners();
  //   return cachedReservations;
  // }
  //
  // Future<ReservationModel?> getReservationById(int reservationId) async {
  //   loading = true;
  //   notifyListeners();
  //
  //   try {
  //     var url = "${Endpoints.reservations}/$reservationId";
  //     var response = await getData(url);
  //
  //     // Vérifier si la requête a réussi
  //     if (response != null && response['data'] != null) {
  //       ReservationModel reservation = ReservationModel.fromJson(response['data']);
  //       currentReservation = reservation;
  //
  //       // Sauvegarder en local
  //       final db = ReservationDatabaseHelper.instance;
  //       final userId = stockage?.read<String>(StockageKeys.userId) ?? 'default_user';
  //       await db.insertOrUpdateReservation(reservation, userId);
  //
  //       loading = false;
  //       notifyListeners();
  //       return reservation;
  //     } else {
  //       print("Aucune donnée reçue pour la réservation $reservationId");
  //     }
  //   } catch (e) {
  //     print("Erreur lors de la récupération de la réservation $reservationId : $e");
  //   }
  //
  //   // Fallback vers le cache local
  //   final db = ReservationDatabaseHelper.instance;
  //   final reservation = await db.getReservationById(reservationId.toString());
  //
  //   loading = false;
  //   notifyListeners();
  //   return reservation;
  // }

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
      if (response.data != null &&
          (response.data['reservation'] != null || response.data['data'] != null)) {

        // Déterminer quelle clé contient la réservation créée
        dynamic reservationJson = response.data['reservation'] ?? response.data['data'];

        if (reservationJson != null) {
          final newReservation = ReservationModel.fromJson(reservationJson);
          reservations.add(newReservation);

          // Sauvegarder en local
          final db = ReservationDatabaseHelper.instance;
          final userId = stockage?.read<String>(StockageKeys.userKey) ?? 'default_user';
          await db.insertOrUpdateReservation(newReservation, userId);

          notifyListeners();
        }
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Failed to create reservation: $e",
        isException: true,
      );
    }
  }

  // Future<HttpResponse> updateReservationStatus(int reservationId, String status) async {
  //   try {
  //     loading = true;
  //     notifyListeners();
  //
  //     final url = "${Endpoints.reservations}/$reservationId/status";
  //     final tkn = stockage?.read<String>(StockageKeys.tokenKey);
  //
  //     Map<String, dynamic> updateData = {
  //       'status': status,
  //     };
  //
  //     HttpResponse response = await patchData(url, updateData, token: tkn);
  //
  //     // Vérifier si la mise à jour a réussi
  //     if (response.data != null && response.statusCode == 200) {
  //       // Mettre à jour localement
  //       final index = reservations.indexWhere((r) => r.reservationId == reservationId);
  //       if (index != -1) {
  //         reservations[index].status = status;
  //       }
  //       if (currentReservation?.reservationId == reservationId) {
  //         currentReservation?.status = status;
  //       }
  //
  //       // Mettre à jour en base locale
  //       final db = ReservationDatabaseHelper.instance;
  //       await db.updateReservationStatus(reservationId.toString(), status);
  //
  //       notifyListeners();
  //     }
  //
  //     loading = false;
  //     notifyListeners();
  //     return response;
  //   } catch (e) {
  //     loading = false;
  //     notifyListeners();
  //     return HttpResponse(
  //       status: false,
  //       errorMsg: "Failed to update reservation status: $e",
  //       isException: true,
  //     );
  //   }
  // }
  //
  // Future<HttpResponse> cancelReservation(int reservationId, String reason) async {
  //   try {
  //     loading = true;
  //     notifyListeners();
  //
  //     final url = "${Endpoints.reservations}/$reservationId/cancel";
  //     final tkn = stockage?.read<String>(StockageKeys.tokenKey);
  //
  //     Map<String, dynamic> cancelData = {
  //       'cancellationReason': reason,
  //     };
  //
  //     HttpResponse response = await postData(url, cancelData, token: tkn);
  //
  //     if (response.data != null && response.statusCode == 200) {
  //       // Mettre à jour localement
  //       final index = reservations.indexWhere((r) => r.reservationId == reservationId);
  //       if (index != -1) {
  //         reservations[index].status = 'CANCELLED';
  //         reservations[index].cancellationReason = reason;
  //       }
  //
  //       // Mettre à jour en base locale
  //       final db = ReservationDatabaseHelper.instance;
  //       await db.updateReservationStatus(reservationId.toString(), 'CANCELLED');
  //
  //       notifyListeners();
  //     }
  //
  //     loading = false;
  //     notifyListeners();
  //     return response;
  //   } catch (e) {
  //     loading = false;
  //     notifyListeners();
  //     return HttpResponse(
  //       status: false,
  //       errorMsg: "Failed to cancel reservation: $e",
  //       isException: true,
  //     );
  //   }
  // }
  //
  // // Méthode pour vider le cache local des réservations
  // Future<void> clearLocalReservations() async {
  //   final db = ReservationDatabaseHelper.instance;
  //   final userId = stockage?.read<String>(StockageKeys.userId) ?? 'default_user';
  //   await db.clearUserReservations(userId);
  //   reservations.clear();
  //   notifyListeners();
  // }
  //
  // // Méthode pour récupérer uniquement les réservations à venir
  // Future<List<ReservationModel>> getUpcomingReservations() async {
  //   final db = ReservationDatabaseHelper.instance;
  //   final userId = stockage?.read<String>(StockageKeys.userId) ?? 'default_user';
  //   return await db.getUpcomingReservations(userId);
  // }
  //
  // // Méthode pour compter les réservations par statut
  // Future<Map<String, int>> getReservationCounts() async {
  //   final db = ReservationDatabaseHelper.instance;
  //   final userId = stockage?.read<String>(StockageKeys.userId) ?? 'default_user';
  //
  //   final all = await db.getReservationsByUser(userId);
  //   final pending = await db.getReservationsByStatus(userId, 'PENDING');
  //   final confirmed = await db.getReservationsByStatus(userId, 'CONFIRMED');
  //   final cancelled = await db.getReservationsByStatus(userId, 'CANCELLED');
  //
  //   return {
  //     'all': all.length,
  //     'pending': pending.length,
  //     'confirmed': confirmed.length,
  //     'cancelled': cancelled.length,
  //   };
  // }
}