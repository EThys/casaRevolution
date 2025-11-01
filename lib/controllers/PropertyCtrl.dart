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

      print("muzolaaaaa${response}");

      // Vérifier si la requête a réussi en cherchant la clé "properties" ou "data"
      if (response != null &&
          (response['properties'] != null || response['data'] != null)) {

        // Déterminer quelle clé contient les données
        List<dynamic> propertiesData = response['properties'] ?? response['data'];

        // Vérifier que la liste n'est pas vide
        if (propertiesData is List && propertiesData.isNotEmpty) {
          List<PropertyModel> properties = propertiesData
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

  Future<PropertyModel?> getPropertyById(int propertyId) async {
    loading = true;
    notifyListeners();

    try {
      var url = "${Endpoints.properties}/$propertyId";
      var response = await getData(url);

      // Vérifier si la requête a réussi
      if (response != null && response['data'] != null) {
        PropertyModel property = PropertyModel.fromJson(response['data']);
        currentProperty = property;
        loading = false;
        notifyListeners();
        return property;
      } else {
        print("Aucune donnée reçue pour la propriété $propertyId");
      }
    } catch (e) {
      print("Erreur lors de la récupération de la propriété $propertyId : $e");
    }

    loading = false;
    notifyListeners();
    return null;
  }

  Future<HttpResponse> createProperty(Map<String, dynamic> propertyData) async {
    try {
      loading = true;
      notifyListeners();

      final url = Endpoints.properties;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      print("URL: $url");
      print("TOKEN: $tkn");

      HttpResponse response = await postData(url, propertyData, token: tkn);
      print("REPONSE: ${response.data}");

      // Vérifier si la création a réussi
      if (response.data != null &&
          (response.data['properties'] != null || response.data['data'] != null)) {

        // Déterminer quelle clé contient la propriété créée
        dynamic propertyJson = response.data['properties'] ?? response.data['data'];

        if (propertyJson != null) {
          final newProperty = PropertyModel.fromJson(propertyJson);
          properties.add(newProperty);
          notifyListeners();
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
        errorMsg: "Failed to create property: $e",
        isException: true,
      );
    }
  }

  Future<HttpResponse> updateProperty(int id, Map<String, dynamic> propertyData) async {
    try {
      loading = true;
      notifyListeners();

      final url = "${Endpoints.properties}/$id";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await patchData(url, propertyData, token: tkn);

      // Vérifier si la mise à jour a réussi
      if (response.data != null &&
          (response.data['property'] != null || response.data['data'] != null)) {

        // Déterminer quelle clé contient la propriété mise à jour
        dynamic propertyJson = response.data['property'] ?? response.data['data'];

        if (propertyJson != null) {
          final updatedProperty = PropertyModel.fromJson(propertyJson);
          final index = properties.indexWhere((p) => p.propertyId == id);
          if (index != -1) {
            properties[index] = updatedProperty;
          }
          if (currentProperty?.propertyId == id) {
            currentProperty = updatedProperty;
          }
          notifyListeners();
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
        errorMsg: "Failed to update property: $e",
        isException: true,
      );
    }
  }

  // Future<HttpResponse> deleteProperty(int id) async {
  //   try {
  //     loading = true;
  //     notifyListeners();
  //
  //     final url = "${Endpoints.properties}/$id";
  //     final tkn = stockage?.read<String>(StockageKeys.tokenKey);
  //
  //     HttpResponse response = await deleteProperty(url, token: tkn);
  //
  //     // Vérifier si la suppression a réussi
  //     if (response.statusCode == 200 || response.statusCode == 204) {
  //       properties.removeWhere((p) => p.propertyId == id);
  //       if (currentProperty?.propertyId == id) {
  //         currentProperty = null;
  //       }
  //       notifyListeners();
  //     }
  //
  //     loading = false;
  //     notifyListeners();
  //     return response;
  //   } catch (e) {
  //     loading = false;
  //     notifyListeners();
  //     return HttpResponse(
  //       status: false,
  //       errorMsg: "Failed to delete property: $e",
  //       isException: true,
  //     );
  //   }
  // }
}

void main() async {
  await GetStorage.init();
  var stockage = GetStorage();
  var ctrl = PropertyController(stockage: stockage);

  // Exemple d'utilisation
  ctrl.getAllProperty();

  // Exemple de création avec images
  // ctrl.createPropertyWithImages(
  //   title: "Belle maison avec jardin",
  //   description: "Maison spacieuse avec 3 chambres et grand jardin",
  //   price: 350000,
  //   surface: 120,
  //   rooms: 5,
  //   bedrooms: 3,
  //   address: "123 Rue de la République",
  //   city: "Paris",
  //   postalCode: "75001",
  //   transactionType: "location",
  //   propertyTypeId: 1,
  //   userId: 1,
  //   latitude: 48.8566,
  //   longitude: 2.3522,
  //   base64Images: [
  //     "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxERADwD3+iiigD//2Q==",
  //   ],
  //   features: [1, 2, 3],
  //   kitchen: 1,
  //   livingRoom: 1,
  //   bathroom: 2,
  //   floor: 1,
  //   commune: "lemba",
  // );
}