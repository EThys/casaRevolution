import 'dart:io';
import 'package:flutter/material.dart';
import '../models/BailleurModel.dart';
import '../utils/Endpoints.dart';
import '../utils/requetes.dart';

class RegisterBailleurCtrl with ChangeNotifier {

  BailleurModel? bailleur;

  Future<HttpResponse> registerBailleur(
      Map<String, dynamic> payload,
      {required int typeCompteId}
      ) async {
    try {
      var url = Endpoints.bailleur;
      print("Payload d'inscription bailleur: ${(payload)}");

      HttpResponse response = await postData(url, payload);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API bailleur: ${(response.data)}");

      // Vérification basée sur le message de succès ou statut HTTP
      if (response.data['message']?.toLowerCase().contains('succès')) {

        // Vérifier si les données du bailleur sont présentes dans la réponse
        if (response.data is Map<String, dynamic>) {
          try {
            BailleurModel bailleur = BailleurModel.fromJson(response.data);
            this.bailleur = bailleur;
            notifyListeners();

            return HttpResponse(
              status: true,
              data: response.data,
              errorMsg: response.data['message'],
            );
          } catch (e) {
            print("Erreur parsing BailleurModel: $e");
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
            "Erreur lors de l'inscription du bailleur";
        return HttpResponse(
          status: false,
          errorMsg: errorMsg,
          data: response.data,
        );
      }
    } catch (e, stackTrace) {
      print("Exception lors de l'inscription du bailleur: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }
}