import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/Endpoints.dart';
import '../utils/requetes.dart';

class RegisterPlombierCtrl with ChangeNotifier {

  Future<HttpResponse> registerPlombier(
      Map<String, dynamic> payload,
      {required int typeCompteId}
      ) async {
    try {
      var url = Endpoints.plombiers;
      print("Payload d'inscription plombier: ${(payload)}");

      HttpResponse response = await postData(url, payload);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API plombier: ${(response.data)}");

      // Vérification basée sur le message de succès ou statut HTTP
      if (response.data['message']?.toLowerCase().contains('succès') ?? false) {
        return HttpResponse(
          status: true,
          data: response.data,
          errorMsg: response.data['message'] ?? "Inscription réussie",
        );
      } else {
        String errorMsg = response.data['message'] ??
            "Erreur lors de l'inscription du plombier";
        return HttpResponse(
          status: false,
          errorMsg: errorMsg,
          data: response.data,
        );
      }
    } catch (e, stackTrace) {
      print("Exception lors de l'inscription du plombier: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  Future<HttpResponse> updatePlombierProfile(
      int plombierId,
      Map<String, dynamic> payload
      ) async {
    try {
      var url = "${Endpoints.plombiers}/$plombierId";
      print("Payload de modification plombier: ${(payload)}");

      HttpResponse response = await putData(url, payload);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API modification plombier: ${(response.data)}");

      if (response.status) {
        return HttpResponse(
          status: true,
          data: response.data,
          errorMsg: response.data['message'] ?? "Profil modifié avec succès",
        );
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
      print("Exception lors de la modification du plombier: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }
}
