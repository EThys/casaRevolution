import 'package:casa/utils/requetes.dart';
import 'package:flutter/cupertino.dart';

import '../utils/Endpoints.dart';

class BailleurCtrl with ChangeNotifier{

  Future<HttpResponse> parrainer(Map<String, dynamic> userData) async {
    try {
      const url = Endpoints.bailleur;
      print("Donnee Bailleurs: ${(userData)}");

      HttpResponse response = await postData(url, userData);

      if (response.data == null) {
        return HttpResponse(
          status: false,
          errorMsg: "Réponse vide du serveur",
          isException: true,
        );
      }

      print("Réponse API: ${(response.data)}");

      return response;
    } catch (e, stackTrace) {
      print("Exception lors de l'inscription: $e");
      print("Stack trace: $stackTrace");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    }
  }

}