import 'package:casa/utils/database/DatabaseHelper.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../models/PropertyModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/requetes.dart';

class PropertyController with ChangeNotifier {
  PropertyController({this.stockage});

  GetStorage? stockage;
  bool loading = false;
  List<PropertyModel> properties = [];
  PropertyModel? currentProperty;


  Future<List<PropertyModel>> getAllProperty() async {
    final url = "${Endpoints.properties}";
    loading = true;
    notifyListeners();

    try {
      // Essayer de récupérer depuis le réseau
      var response = await getData(url);

      if (response != null && response['success'] == true) {
        List<PropertyModel> properties = (response['data'] as List)
            .map<PropertyModel>((e) => PropertyModel.fromJson(e))
            .toList();

        // Sauvegarder en local
        final db = DatabaseHelper.instance;
        for (var property in properties) {
          await db.insertOrUpdateProperty(property);
        }

        this.properties = properties;
        loading = false;
        notifyListeners();
        return properties;
      }
    } catch (e) {
      print("Erreur réseau: $e");
      // Continuer avec le cache si échec réseau
    }

    // Si échec réseau ou réponse invalide, charger depuis SQLite
    final db = DatabaseHelper.instance;
    final cachedProperties = await db.getAllProperties();

    this.properties = cachedProperties;
    loading = false;
    notifyListeners();
    return cachedProperties;
  }


  void getPropertyById(int propertyId) async {
    loading = true;
    notifyListeners();

    try {
      var url = "${Endpoints.properties}/$propertyId";
      var response = await getData(url);

      if (response != null) {
        PropertyModel property = PropertyModel.fromJson(response['data']);
        loading = false;
        notifyListeners();
      } else {
        print("Aucune donnée reçue pour la propriété $propertyId");
      }
    } catch (e) {
      print("Erreur lors de la récupération de la propriété $propertyId : $e");
    }

    loading = false;
    notifyListeners();
    return null;  // Retourne null si échec ou pas trouvé
  }

  Future<HttpResponse> createProperty(Map<String, dynamic> propertyData) async {
    try {
      loading = true;
      notifyListeners();

      final url = Endpoints.properties;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      print("URLLLLLLLLLLLLLLLLLLLLLLLL${url}");
      print("TOKENNNNNNNNNNNNN${tkn}");

      HttpResponse response = await postData(url, propertyData, token: tkn);
      print("REPONSEEEEEEEEEEEEEEEEEEE${response.data}");

      if (response.status == 201) {
        final newProperty = PropertyModel.fromJson(response.data);
        properties.add(newProperty);
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Failed to create property",
        isException: true,
      );
    }
  }

  // Update property
  Future<HttpResponse> updateProperty(String id, Map<String, dynamic> propertyData) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.properties}/$id";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await patchData(url, propertyData, token: tkn);

      if (response.status == 200) {
        final updatedProperty = PropertyModel.fromJson(response.data);
        final index = properties.indexWhere((p) => p.PropertyId == id);
        if (index != -1) {
          properties[index] = updatedProperty;
        }
        if (currentProperty?.PropertyId == id) {
          currentProperty = updatedProperty;
        }
      }

      loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      loading = false;
      notifyListeners();
      return HttpResponse(
        status: false,
        errorMsg: "Failed to update property",
        isException: true,
      );
    }
  }
}

void main() async{
  await GetStorage.init();
  var stockage = GetStorage();
  var ctrl=PropertyController(stockage: stockage);
  ctrl.getAllProperty();
  // ctrl.createProperty(
  //     {
  //       "title": "Belle maison avec jardin",
  //       "description": "Maison spacieuse avec 3 chambres et grand jardin",
  //       "price": 350000,
  //       "commune":"lemba",
  //       "surface": 120,
  //       "rooms": 5,
  //       "bedrooms": 3,
  //       "floor": 1,
  //       "address": "123 Rue de la République",
  //       "city": "Paris",
  //       "postalCode": "75001",
  //       "sold": false,
  //       "transactionType": "location",
  //       "PropertyTypeId": 1,
  //       "UserId": 1,
  //       "latitude": 48.8566,
  //       "longitude": 2.3522,
  //       "isAvailable": true,
  //       "features": [1, 2,3],
  //       "images": [
  //         {
  //           "base64": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD3+iiigD//2Q==",
  //           "isMain": true
  //         },
  //         {
  //           "base64": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
  //           "isMain": false
  //         }
  //       ]
  //     }
  // );
}