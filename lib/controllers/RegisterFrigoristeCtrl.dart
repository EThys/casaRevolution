import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/Endpoints.dart';
import '../utils/requetes.dart';

class RegisterFrigoristeCtrl with ChangeNotifier {

  Future<HttpResponse> registerFrigoriste(
      Map<String, dynamic> payload,
      {required int typeCompteId}
      ) async {
    try {
      var url = Endpoints.frigoristes;
      print("Payload d'inscription frigoriste: ${(payload)}");

      HttpResponse response = await postData(url, payload);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API frigoriste: ${(response.data)}");

      // Vérification basée sur le message de succès ou statut HTTP
      if (response.data['message']?.toLowerCase().contains('succès') ?? false) {
        return HttpResponse(
          status: true,
          data: response.data,
          errorMsg: response.data['message'] ?? "Inscription réussie",
        );
      } else {
        String errorMsg = response.data['message'] ??
            "Erreur lors de l'inscription du frigoriste";
        return HttpResponse(
          status: false,
          errorMsg: errorMsg,
          data: response.data,
        );
      }
    } catch (e, stackTrace) {
      print("Exception lors de l'inscription du frigoriste: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

  Future<HttpResponse> updateFrigoristeProfile(
      int frigoristeId,
      Map<String, dynamic> payload
      ) async {
    try {
      var url = "${Endpoints.frigoristes}/$frigoristeId";
      print("Payload de modification frigoriste: ${(payload)}");

      HttpResponse response = await putData(url, payload);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API modification frigoriste: ${(response.data)}");

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
      print("Exception lors de la modification du frigoriste: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }
}
