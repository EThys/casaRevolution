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


  Future<List<PropertyVisitModel>> getAllPropertyVisits() async {
    var url = "${Endpoints.allVisits}";
    final tkn = stockage?.read<String>(StockageKeys.tokenKey);
    print("tokennnnnnnn${tkn}",);
    loading = true;
    notifyListeners();

    print("Début de la récupération des visits");

    try {
      var reponse = await getData(url,token:tkn );
      print("Réponse du serveur: $reponse");

      List<PropertyVisitModel> result = [];

      if (reponse != null && reponse['success'] == true) {
        print("Données reçues du serveur");

        // Correction ici: on accède au tableau 'data' dans la réponse
        if (reponse['data']['data'] is List) {
          List<PropertyVisitModel> visits = (reponse['data']['data'] as List)
              .map<PropertyVisitModel>((e) => PropertyVisitModel.fromJson(e))
              .toList();
          propertyVisits = visits;
          await stockage?.write(StockageKeys.propreties, propertyVisits);
          notifyListeners();
          print("${visits.length} propriétés stockées");
          result = visits;
        } else {
          print("Le champ 'data' n'est pas une liste");
        }
      } else {
        print("Utilisation des données locales");
        var localData = stockage?.read(StockageKeys.propreties);
        result = localData != null
            ? (localData as List).map((e) => PropertyVisitModel.fromJson(e)).toList()
            : [];
        propertyVisits = result;
        print("${result.length} propriétés locales chargées");
      }

      loading = false;
      notifyListeners();
      return result;
    } catch (e) {
      print("Erreur lors de la récupération: $e");
      loading = false;
      propertyVisits = [];
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
}

void main(){
  var test=PropertyVisitCtrl();
  test.getAllPropertyVisits();
}