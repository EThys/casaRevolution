import 'package:casa/utils/database/ReservationDatabaseHelper.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../models/ReservationModel.dart';
import 'package:flutter/foundation.dart';

import '../utils/Endpoints.dart';
import '../utils/log_redaction.dart';
import '../utils/StockageKeys.dart';
import '../utils/requetes.dart'
    show getData, getDataAllowErrorJson, postData, patchData, putData, HttpResponse;

class ReservationController with ChangeNotifier {
  ReservationController({this.stockage});

  GetStorage? stockage;
  bool loading = false;
  List<ReservationModel> reservations = [];
  ReservationModel? currentReservation;

  /// Mis à `true` si une réponse réservations indique un compte non certifié (rediriger vers [IdentityVerificationPage]).
  bool uncertifiedAccountBlocked = false;

  // Récupérer l'ID de l'utilisateur connecté (userId)
  String? _getCurrentUserId() {
    final dynamic userData = stockage?.read(StockageKeys.userKey);
    final userId = userData?['user']?['userId'] ?? userData?['userId'];
    return userId?.toString();
  }

  int _currentUserIdAsInt() {
    final s = _getCurrentUserId();
    if (s == null || s.isEmpty) return 0;
    return int.tryParse(s) ?? 0;
  }

  /// Base URL (sans id) pour PUT `/protected/reservations/.../update/status/{id}`, ou null → fallback delete legacy.
  String? _protectedReservationStatusBase(ReservationModel r) {
    if (r.chambreId != null) return Endpoints.updateReservationChambreStatusProtected;
    if (r.terrainId != null) return Endpoints.updateReservationTerrainStatusProtected;
    if (r.bureauId != null) return Endpoints.updateReservationBureauStatusProtected;
    if (r.vacanceId != null) return Endpoints.updateReservationVacanceStatusProtected;
    if (r.festiveId != null) return Endpoints.updateReservationFestiveStatusProtected;
    if (r.funeraireId != null) return Endpoints.updateReservationFuneraireStatusProtected;
    if (r.hotelId != null) return Endpoints.updateReservationChambreStatusProtected;
    final t = (r.type ?? '').toUpperCase();
    if (t.contains('TERRAIN')) return Endpoints.updateReservationTerrainStatusProtected;
    if (t.contains('BUREAU')) return Endpoints.updateReservationBureauStatusProtected;
    if (t.contains('VACANCE')) return Endpoints.updateReservationVacanceStatusProtected;
    if (t.contains('FESTIVE')) return Endpoints.updateReservationFestiveStatusProtected;
    if (t.contains('FUNERAIRE') || t.contains('FUNÉRAIRE')) {
      return Endpoints.updateReservationFuneraireStatusProtected;
    }
    if (t.contains('CHAMBRE') || t.contains('HOTEL') || t.contains('HÔTEL')) {
      return Endpoints.updateReservationChambreStatusProtected;
    }
    return Endpoints.updateReservationStandardStatusProtected;
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

  /// Message API typique : « Opération non autorisée,votre compte n'est pas certifié. »
  static bool messageIndicatesUncertifiedAccount(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    final s = raw.toLowerCase();
    return (s.contains('certif') && s.contains('pas')) ||
        s.contains("n'est pas certif") ||
        s.contains('nest pas certif') ||
        s.contains('non certifie') ||
        s.contains('non certifié');
  }

  void _noteUncertifiedIfResponse(dynamic response) {
    if (response is! Map) return;
    final map = Map<String, dynamic>.from(response as Map);
    String? msg = map['message']?.toString() ??
        map['detailMessage']?.toString() ??
        map['error']?.toString();
    final data = map['data'];
    if (!messageIndicatesUncertifiedAccount(msg) && data is Map) {
      msg = data['message']?.toString() ?? data['detailMessage']?.toString();
    }
    if (messageIndicatesUncertifiedAccount(msg)) {
      uncertifiedAccountBlocked = true;
      if (kDebugMode) {
        print('🔒 [ReservationController] Compte non certifié (API): $msg');
      }
    }
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

    print("🔍 Récupération complète des réservations pour user: $userId (Standard + Spécialisées)");

    loading = true;
    notifyListeners();

    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    List<ReservationModel> allUserReservations = [];

    // Liste des endpoints à interroger pour obtenir toutes les réservations de l'utilisateur
    final endpointsToFetch = [
      "${Endpoints.reservationsProtected}/${Endpoints.reservationsByUser}/$userId",
      "${Endpoints.reservationsVacanceByUser}$userId",
      "${Endpoints.reservationsTerrainByUser}$userId",
      "${Endpoints.reservationsFuneraireByUser}$userId",
      "${Endpoints.reservationsFestiveByUser}$userId",
      "${Endpoints.reservationsBureauByUser}$userId",
      "${Endpoints.reservationsChambreByUser}$userId",
    ];

    try {
      // Exécuter toutes les requêtes en parallèle pour plus de performance
      await Future.wait(endpointsToFetch.map((url) async {
        try {
          print("🌐 Requête réservations type: $url");
          var response = await getDataAllowErrorJson(url, token: tkn);
          _noteUncertifiedIfResponse(response);

          // L'API peut retourner {"reservation": [...]} ou {"data": [...]} ou {"reservations": [...]}
          if (response != null && (response['reservation'] != null || response['data'] != null || response['reservations'] != null)) {
            List<dynamic> reservationsData = response['reservation'] ?? response['reservations'] ?? response['data'];

            if (reservationsData is List) {
              print("✅ [ReservationController] ${reservationsData.length} réservations reçues de $url");
              for (var item in reservationsData) {
                if (item is Map) {
                  try {
                    final reservation = ReservationModel.fromJson(Map<String, dynamic>.from(item));
                    allUserReservations.add(reservation);
                  } catch (e) {
                    print("❌ Error parsing reservation from $url: $e");
                  }
                }
              }
            }
          }
        } catch (e) {
          print("⚠️ Échec partiel de récupération depuis l'endpoint $url: $e");
        }
      }));

      // Supprimer les doublons potentiels si certains endpoints retournent la même chose
      final seenIds = <int>{};
      allUserReservations = allUserReservations.where((r) {
        if (r.reservationId == null) return true;
        return seenIds.add(r.reservationId!);
      }).toList();

      if (allUserReservations.isNotEmpty) {
        // Trier par date de création (la plus récente en premier)
        allUserReservations.sort((a, b) {
          final dateA = a.createdAt ?? "";
          final dateB = b.createdAt ?? "";
          return dateB.compareTo(dateA);
        });

        print("👤 Total des réservations récupérées (tous types confondus): ${allUserReservations.length}");

        // Sauvegarder en local pour le mode hors-ligne
        final db = ReservationDatabaseHelper.instance;
        await db.clearUserReservations(userId); // Vider le cache pour cet utilisateur avant de rafraîchir
        for (var reservation in allUserReservations) {
          await db.insertOrUpdateReservation(reservation, userId);
        }

        this.reservations = allUserReservations;
        loading = false;
        notifyListeners();
        return allUserReservations;
      }
    } catch (e) {
      print("❌ Erreur lors de la récupération des réservations: $e");
    }

    // Fallback vers le cache local en cas d'erreur ou si aucune donnée n'est renvoyée par l'API
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
      final url = "${Endpoints.reservationsProtected}/${Endpoints.reservationsByUser}/$userId?status=$status";
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
      var url = "${Endpoints.reservationsProtected}/$reservationId";
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
        String? endpoint,
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
          const errorMsg =
              "Vous ne pouvez pas réserver votre propre bien.";
          return HttpResponse(
            status: false,
            data: {'error': errorMsg},
            errorMsg: errorMsg,
          );
        }

        // Empêcher la duplication d'une réservation en attente pour le même bien / chambre
        final chambreIdStr = reservationData['chambreId']?.toString();
        if (chambreIdStr != null && chambreIdStr.isNotEmpty) {
          final hasPendingChambre = reservations.any(
            (r) =>
                r.user?.userId?.toString() == userId &&
                r.chambreId?.toString() == chambreIdStr &&
                (r.status?.toUpperCase() == 'PENDING'),
          );
          if (hasPendingChambre) {
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
        } else {
          final propertyId = (reservationData['propertyId'] ??
              reservationData['terrainId'] ??
              reservationData['bureauId'] ??
              reservationData['vacanceId'] ??
              reservationData['festiveId'] ??
              reservationData['funeraireId'] ??
              reservationData['hotelId'])?.toString();

          if (propertyId != null) {
            final hasPending = reservations.any(
              (r) {
                final rPropertyId = (r.property?.propertyId ??
                    r.terrainId ??
                    r.bureauId ??
                    r.vacanceId ??
                    r.festiveId ??
                    r.funeraireId ??
                    r.hotelId)?.toString();
                return r.user?.userId?.toString() == userId &&
                    rPropertyId == propertyId &&
                    (r.status?.toUpperCase() == 'PENDING');
              },
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
        }
      }

      final url = endpoint ?? Endpoints.createReservation;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      if (kDebugMode) {
        print("URL: $url");
        print(describeSecretPresence(tkn, name: 'TOKEN'));
      }

      HttpResponse response = await postData(url, reservationData, token: tkn);
      if (kDebugMode && response.data is Map) {
        final m = response.data as Map;
        print(
            "REPONSE (résumé): clés=${m.keys.toList()}, message=${m['message']}");
      }

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

          // Déclencher la notification propriétaire/partenaires (backend) si disponible.
          // Certains backends n'émettent plus le push sur POST réservation : on appelle explicitement l'endpoint.
          try {
            final rid = newReservation.reservationId;
            if (rid != null) {
              final notifUrl = "${Endpoints.partnersReservationNotification}$rid";
              // Endpoint private: token utilisateur requis.
              await getDataAllowErrorJson(notifUrl, token: tkn);
              if (kDebugMode) {
                print("🔔 [ReservationController] Notification partners déclenchée: $notifUrl");
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print("⚠️ [ReservationController] Notification partners non déclenchée: $e");
            }
          }

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

  /// Annule une réservation. Si [reservation] correspond à un type spécialisé (terrain, bureau, etc.),
  /// utilise `PUT .../protected/reservations/{type}/update/status/{id}` avec `{ status: CANCELLED, reason, userId }`.
  Future<HttpResponse> cancelReservation(
    int reservationId,
    String reason, {
    ReservationModel? reservation,
  }) async {
    try {
      loading = true;
      notifyListeners();

      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      final base = reservation != null
          ? _protectedReservationStatusBase(reservation)
          : Endpoints.updateReservationStandardStatusProtected;

      final url = "$base$reservationId";
      final HttpResponse response = await putData(
        url,
        {
          'status': 'CANCELLED',
          'reason': reason,
          'userId': _currentUserIdAsInt(),
        },
        token: tkn,
      );

      if (response.status == true) {
        final index = reservations.indexWhere((r) => r.reservationId == reservationId);
        if (index != -1) {
          reservations[index].status = 'CANCELLED';
          reservations[index].cancellationReason = reason;
        }

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

    print("🔍 Récupération complète des réservations hôte pour user: $userId (Tous types)");

    loading = true;
    notifyListeners();

    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    List<ReservationModel> allHostReservations = [];

    // Liste des endpoints à interroger pour obtenir toutes les réservations reçues par l'hôte
    final hostEndpointsToFetch = [
      "${Endpoints.reservationsHost}$userId",
      "${Endpoints.reservationsVacanceByHost}$userId",
      "${Endpoints.reservationsTerrainByHost}$userId",
      "${Endpoints.reservationsFuneraireByHost}$userId",
      "${Endpoints.reservationsFestiveByHost}$userId",
      "${Endpoints.reservationsBureauByHost}$userId",
      "${Endpoints.reservationsChambreByHost}$userId",
    ];

    try {
      // Exécuter toutes les requêtes en parallèle pour plus de performance
      await Future.wait(hostEndpointsToFetch.map((url) async {
        try {
          print("🌐 Requête réservations hôte: $url");
          var response = await getDataAllowErrorJson(url, token: tkn);
          _noteUncertifiedIfResponse(response);

          // L'API peut retourner {"reservation": [...]} ou {"data": [...]}
          if (response != null && (response['reservation'] != null || response['data'] != null || response['reservations'] != null)) {
            List<dynamic> reservationsData = response['reservation'] ?? response['reservations'] ?? response['data'];

            if (reservationsData is List) {
              for (var item in reservationsData) {
                if (item is Map) {
                  try {
                    final reservation = ReservationModel.fromJson(Map<String, dynamic>.from(item));
                    allHostReservations.add(reservation);
                  } catch (e) {
                    print("❌ Error parsing host reservation from $url: $e");
                  }
                }
              }
            }
          }
        } catch (e) {
          print("⚠️ Échec de récupération depuis l'endpoint hôte $url: $e");
        }
      }));

      // Supprimer les doublons potentiels
      final seenIds = <int>{};
      allHostReservations = allHostReservations.where((r) {
        if (r.reservationId == null) return true;
        return seenIds.add(r.reservationId!);
      }).toList();

      if (allHostReservations.isNotEmpty) {
        // Trier par date de création (la plus récente en premier)
        allHostReservations.sort((a, b) {
          final dateA = a.createdAt ?? "";
          final dateB = b.createdAt ?? "";
          return dateB.compareTo(dateA);
        });

        print("👤 Total des réservations hôte récupérées: ${allHostReservations.length}");
        
        loading = false;
        notifyListeners();
        return allHostReservations;
      }
    } catch (e) {
      print("❌ Erreur lors de la récupération des réservations hôte: $e");
    }

    loading = false;
    notifyListeners();
    return [];
  }

  /// Réservations pour une chambre (`GET` [Endpoints.reservationsChambreByChambreEntity]`{chambreId}`).
  Future<List<ReservationModel>> fetchReservationsForChambre(int chambreId) async {
    if (chambreId <= 0) return [];
    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    final url = "${Endpoints.reservationsChambreByChambreEntity}$chambreId";
    final List<ReservationModel> out = [];
    try {
      final response = await getDataAllowErrorJson(url, token: tkn);
      if (response != null &&
          (response['reservation'] != null || response['data'] != null || response['reservations'] != null)) {
        final reservationsData =
            response['reservation'] ?? response['reservations'] ?? response['data'];
        if (reservationsData is List) {
          for (final item in reservationsData) {
            if (item is Map) {
              try {
                out.add(ReservationModel.fromJson(Map<String, dynamic>.from(item)));
              } catch (e) {
                print("❌ fetchReservationsForChambre parse: $e");
              }
            }
          }
        }
      }
    } catch (e) {
      print("⚠️ fetchReservationsForChambre: $e");
    }
    return out;
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

  // Valider une réservation et envoyer une notification
  Future<HttpResponse> validateReservation(int reservationId, bool isValid) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.validateReservationNotification}$reservationId/$isValid";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      print("🌐 [ReservationController] Validation réservation: $url");

      // La requête est spécifiée comme PUT par l'utilisateur
      HttpResponse response = await putData(url, {}, token: tkn);

      print("📡 [ReservationController] Réponse API détaillée: ${response.data}");

      if (response.status == true) {
        print("✅ [ReservationController] Réservation $reservationId validée avec succès");

        // Mettre à jour localement si nécessaire
        final index = reservations.indexWhere((r) => r.reservationId == reservationId);
        if (index != -1) {
          reservations[index].status = isValid ? 'CONFIRMED' : 'REJECTED';
        }

        // await getAllReservations(); // Supprimé pour éviter de ralentir l'UI (déjà actualisé par l'appelant)
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      print("❌ [ReservationController] Erreur validation réservation: $e");
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Échec de la validation: $e",
        isException: true,
      );
    }
  }
}