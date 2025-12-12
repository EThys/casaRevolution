import 'dart:io';
import 'package:flutter/material.dart';
import '../models/LocataireModel.dart';
import '../utils/Endpoints.dart';
import '../utils/requetes.dart';

class RegisterLocataireCtrl with ChangeNotifier {
  LocataireModel? locataire;

  Future<HttpResponse> registerLocataire(
      Map<String, dynamic> payload,
      {required int typeCompteId}
      ) async {
    try {
      var url = Endpoints.locataire;
      print("Payload d'inscription locataire: ${(payload)}");

      HttpResponse response = await postData(url, payload);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }


      print("Réponse API locataire: ${(response.data)}");

      // Vérification basée sur le message de succès ou statut HTTP
      if (response.data['message']?.toLowerCase().contains('succès')) {

        // Vérifier si les données du locataire sont présentes dans la réponse
        if (response.data is Map<String, dynamic>) {
          try {
            LocataireModel locataire = LocataireModel.fromJson(response.data);
            this.locataire = locataire;
            notifyListeners();

            return HttpResponse(
              status: true,
              data: response.data,
              errorMsg: response.data['message'],
            );
          } catch (e) {
            print("Erreur parsing LocataireModel: $e");
            return HttpResponse(
              status: true,
              data: response.data,
              errorMsg: response.data['message'] ?? "Inscription réussie",
            );
          }
        } else {
          return HttpResponse(
            status: true,
            data: response.data,
            errorMsg: response.data['message'] ?? "Inscription réussie",
          );
        }
      } else {
        String errorMsg = response.data['message'] ??
            "Erreur lors de l'inscription du locataire";
        return HttpResponse(
          status: false,
          errorMsg: errorMsg,
          data: response.data,
        );
      }
    } catch (e, stackTrace) {
      print("Exception lors de l'inscription du locataire: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  Future<HttpResponse> updateLocataireProfile(
      int locataireId,
      Map<String, dynamic> payload
      ) async {
    try {
      var url = "${Endpoints.locataire}/$locataireId";
      print("Payload de modification locataire: ${(payload)}");

      HttpResponse response = await putData(url, payload);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API modification locataire: ${(response.data)}");

      if (response.status) {
        try {
          LocataireModel locataire = LocataireModel.fromJson(response.data);
          this.locataire = locataire;
          notifyListeners();

          return HttpResponse(
            status: true,
            data: response.data,
            errorMsg: response.data['message'] ?? "Profil modifié avec succès",
          );
        } catch (e) {
          print("Erreur parsing LocataireModel: $e");
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
      print("Exception lors de la modification du locataire: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }
}