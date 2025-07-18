import 'package:casa/models/PropertyVisitModel.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/material.dart';

import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/requetes.dart';

class PropertyVisitCtrl with ChangeNotifier{
  PropertyVisitCtrl({this.stockage});

  GetStorage? stockage;
  bool loading = false;
  List<PropertyVisitModel> propertyVisits = [];


  // Future<List<PropertyVisitModel>> getAllPropertyVisits() async {
  //   var url = "${Endpoints.allVisits}";
  //   final tkn = stockage?.read<String>(StockageKeys.tokenKey);
  //   print("tokennnnnnnn${tkn}",);
  //   loading = true;
  //   notifyListeners();
  //
  //   print("Début de la récupération des visits");
  //
  //   try {
  //     var reponse = await getData(url,token:tkn );
  //     print("Réponse du serveur: $reponse");
  //
  //     List<PropertyVisitModel> result = [];
  //
  //     if (reponse != null && reponse['success'] == true) {
  //       print("Données reçues du serveur");
  //
  //       // Correction ici: on accède au tableau 'data' dans la réponse
  //       if (reponse['data']['data'] is List) {
  //         List<PropertyVisitModel> visits = (reponse['data']['data'] as List)
  //             .map<PropertyVisitModel>((e) => PropertyVisitModel.fromJson(e))
  //             .toList();
  //         propertyVisits = visits;
  //         await stockage?.write(StockageKeys.propreties, propertyVisits);
  //         notifyListeners();
  //         print("${visits.length} propriétés stockées");
  //         result = visits;
  //       } else {
  //         print("Le champ 'data' n'est pas une liste");
  //       }
  //     } else {
  //       print("Utilisation des données locales");
  //       var localData = stockage?.read(StockageKeys.propreties);
  //       result = localData != null
  //           ? (localData as List).map((e) => PropertyVisitModel.fromJson(e)).toList()
  //           : [];
  //       propertyVisits = result;
  //       print("${result.length} propriétés locales chargées");
  //     }
  //
  //     loading = false;
  //     notifyListeners();
  //     return result;
  //   } catch (e) {
  //     print("Erreur lors de la récupération: $e");
  //     loading = false;
  //     propertyVisits = [];
  //     notifyListeners();
  //     return [];
  //   }
  // }

  Future<List<PropertyVisitModel>> getVisitsByUser(String userId) async {
    var url = "${Endpoints.visitsByUser}/$userId";
    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    print("Token: $tkn");
    loading = true;
    notifyListeners();

    print("Début de la récupération des visites pour l'utilisateur $userId");

    try {
      var reponse = await getData(url, token: tkn);
      print("Réponse du serveur: $reponse");

      List<PropertyVisitModel> result = [];

      if (reponse != null && reponse['success'] == true) {
        print("Données reçues du serveur");

        if (reponse['data'] is List) {
          List<PropertyVisitModel> visits = (reponse['data'] as List)
              .map<PropertyVisitModel>((e) => PropertyVisitModel.fromJson(e))
              .toList();

          await stockage?.write('${StockageKeys.userVisits}_$userId', visits);

          result = visits;
          print("${visits.length} visites trouvées pour l'utilisateur");
        } else if (reponse['data']['data'] is List) {

          List<PropertyVisitModel> visits = (reponse['data']['data'] as List)
              .map<PropertyVisitModel>((e) => PropertyVisitModel.fromJson(e))
              .toList();

          await stockage?.write('${StockageKeys.userVisits}_$userId', visits);
          result = visits;
          print("${visits.length} visites trouvées (format paginé)");
        } else {
          print("Le format des données n'est pas reconnu");
        }
      } else {
        print("Utilisation des données locales");
        var localData = stockage?.read('${StockageKeys.userVisits}_$userId');
        result = localData != null
            ? (localData as List).map((e) => PropertyVisitModel.fromJson(e)).toList()
            : [];
        print("${result.length} visites locales chargées");
      }

      propertyVisits = result;
      loading = false;
      notifyListeners();
      return result;
    } catch (e) {
      print("Erreur lors de la récupération des visites utilisateur: $e");
      loading = false;
      notifyListeners();
      return [];
    }
  }

  Future<HttpResponse> createVisitProperty(Map<String, dynamic> propertyVisitData) async {
    try {
      loading = true;
      notifyListeners();

      final url = Endpoints.storeVisit;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      print("URLLLLLLLLLLLLLLLLLLLLLLLL${url}");
      print("TOKENNNNNNNNNNNNN${tkn}");

      HttpResponse response = await postData(url, propertyVisitData, token: tkn);
      print("REPONSEEEEEEEEEEEEEEEEEEE${response.data}");

      if (response.status == 201) {
        final newPropertyVisit = PropertyVisitModel.fromJson(response.data);
        propertyVisits.add(newPropertyVisit);
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Failed to create propertyvisit",
        isException: true,
      );
    }
  }
  Future<HttpResponse> changeVisitStatus({
    required String visitId,
    required Map<String, dynamic> requestData
  }) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.visits}/$visitId/status";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      print("URL: $url");
      print("Token: $tkn");

      // Préparation des données
      HttpResponse response = await postData(url, requestData,token: tkn);

      print("Réponse du serveur: ${response.data}");

      if (response.status == 200 && response.data['success'] == true) {
        final updatedVisit = PropertyVisitModel.fromJson(response.data['data']);
        final index = propertyVisits.indexWhere((v) => v.propertyVisitId == visitId);
        if (index != -1) {
          propertyVisits[index] = updatedVisit;
        }

        // Mettre à jour également dans le cache utilisateur spécifique si vous l'utilisez
        await _updateLocalVisit(updatedVisit);
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      print("Erreur lors du changement de statut: $e");
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Échec de la mise à jour du statut de la visite",
        isException: true,
      );
    }
  }

// Méthode helper pour mettre à jour le cache local
  Future<void> _updateLocalVisit(PropertyVisitModel updatedVisit) async {
    try {
      // Mise à jour dans le cache global
      var allVisits = stockage?.read<List<dynamic>>(StockageKeys.propreties) ?? [];
      final index = allVisits.indexWhere((v) => v['propertyVisitId'] == updatedVisit.propertyVisitId);
      if (index != -1) {
        allVisits[index] = updatedVisit.toJson();
        await stockage?.write(StockageKeys.propreties, allVisits);
      }

      // Mise à jour dans le cache utilisateur spécifique (si utilisé)
      final userId = updatedVisit.userId; // Adaptez selon votre modèle
      if (userId != null) {
        var userVisits = stockage?.read<List<dynamic>>('${StockageKeys.userVisits}_$userId') ?? [];
        final userIndex = userVisits.indexWhere((v) => v['propertyVisitId'] == updatedVisit.propertyVisitId);
        if (userIndex != -1) {
          userVisits[userIndex] = updatedVisit.toJson();
          await stockage?.write('${StockageKeys.userVisits}_$userId', userVisits);
        }
      }
    } catch (e) {
      print("Erreur lors de la mise à jour locale: $e");
    }
  }
}

// void main(){
//   var test=PropertyVisitCtrl();
//   test.getVisitsByUser("12");
// }