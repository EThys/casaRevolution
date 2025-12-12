import 'dart:io';
import 'package:flutter/material.dart';
import '../models/CommissionaireModel.dart';
import '../utils/Endpoints.dart';
import '../utils/requetes.dart';

class RegisterCommissionnaireCtrl with ChangeNotifier {
  CommissionnaireModel? commissionnaire;

  Future<HttpResponse> registerCommissionnaire(
      Map<String, dynamic> payload,
      {required int typeCompteId}
      ) async {
    try {
      var url = Endpoints.commissionnaire;
      print("Payload d'inscription commissionnaire: ${(payload)}");

      // Le payload est déjà structuré correctement, pas besoin de modification
      HttpResponse response = await postData(url, payload);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API commissionnaire: ${(response.data)}");

      // Vérification basée sur le message de succès ou statut HTTP
      if (response.data['message']?.toLowerCase().contains('succès')) {

        // Vérifier si les données du commissionnaire sont présentes dans la réponse
        if (response.data is Map<String, dynamic>) {
          try {
            // La réponse peut contenir les données du commissionnaire créé
            CommissionnaireModel commissionnaire = CommissionnaireModel.fromJson(response.data);
            this.commissionnaire = commissionnaire;
            notifyListeners();

            return HttpResponse(
              status: true,
              data: response.data,
              errorMsg: response.data['message'],
            );
          } catch (e) {
            print("Erreur parsing CommissionnaireModel: $e");
            // Si le parsing échoue mais l'API a répondu positivement
            return HttpResponse(
              status: true,
              data: response.data,
              errorMsg: response.data['message'] ?? "Inscription réussie",
            );
          }
        } else {
          // Réponse positive mais structure de données différente
          return HttpResponse(
            status: true,
            data: response.data,
            errorMsg: response.data['message'] ?? "Inscription réussie",
          );
        }
      } else {
        // Gestion des erreurs - utiliser le message de l'API ou un message par défaut
        String errorMsg = response.data['message'] ??
            "Erreur lors de l'inscription du commissionnaire";
        return HttpResponse(
          status: false,
          errorMsg: errorMsg,
          data: response.data,
        );
      }
    } catch (e, stackTrace) {
      print("Exception lors de l'inscription du commissionnaire: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  Future<HttpResponse> updateCommissionnaireProfile(
      int commissionnaireId,
      Map<String, dynamic> payload
      ) async {
    try {
      var url = "${Endpoints.commissionnaire}/$commissionnaireId";
      print("Payload de modification commissionnaire: ${(payload)}");

      HttpResponse response = await putData(url, payload);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API modification commissionnaire: ${(response.data)}");

      if (response.status) {
        try {
          CommissionnaireModel commissionnaire = CommissionnaireModel.fromJson(response.data);
          this.commissionnaire = commissionnaire;
          notifyListeners();

          return HttpResponse(
            status: true,
            data: response.data,
            errorMsg: response.data['message'] ?? "Profil modifié avec succès",
          );
        } catch (e) {
          print("Erreur parsing CommissionnaireModel: $e");
          return HttpResponse(
            status: true,
            data: response.data,
            errorMsg: response.data['message'] ?? "Profil modifié avec succès",
          );
        }
      } else {
        String errorMsg = response.data['message'] ??
            response.errorMsg ??
            "Erreur lors de la modification du profil";
        return HttpResponse(
          status: false,
          errorMsg: errorMsg,
          data: response.data,
        );
      }
    } catch (e, stackTrace) {
      print("Exception lors de la modification du commissionnaire: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }
}