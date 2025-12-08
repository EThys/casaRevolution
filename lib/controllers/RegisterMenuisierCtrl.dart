import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/Endpoints.dart';
import '../utils/requetes.dart';

class RegisterMenuisierCtrl with ChangeNotifier {

  Future<HttpResponse> registerMenuisier(
      Map<String, dynamic> payload,
      {required int typeCompteId}
      ) async {
    try {
      var url = Endpoints.menuisiers;
      print("Payload d'inscription menuisier: ${(payload)}");

      HttpResponse response = await postData(url, payload);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API menuisier: ${(response.data)}");

      // Vérification basée sur le message de succès ou statut HTTP
      if (response.data['message']?.toLowerCase().contains('succès') ?? false) {
        return HttpResponse(
          status: true,
          data: response.data,
          errorMsg: response.data['message'] ?? "Inscription réussie",
        );
      } else {
        String errorMsg = response.data['message'] ??
            "Erreur lors de l'inscription du menuisier";
        return HttpResponse(
          status: false,
          errorMsg: errorMsg,
          data: response.data,
        );
      }
    } catch (e, stackTrace) {
      print("Exception lors de l'inscription du menuisier: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  Future<HttpResponse> updateMenuisierProfile(
      int menuisierId,
      Map<String, dynamic> payload
      ) async {
    try {
      var url = "${Endpoints.menuisiers}/$menuisierId";
      print("Payload de modification menuisier: ${(payload)}");

      HttpResponse response = await putData(url, payload);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API modification menuisier: ${(response.data)}");

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
      print("Exception lors de la modification du menuisier: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }
}
