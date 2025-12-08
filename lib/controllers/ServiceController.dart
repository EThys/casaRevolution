import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ServiceModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/requetes.dart' show getData, postData, patchData, deleteData, HttpResponse;

class ServiceController with ChangeNotifier {
  ServiceController({this.stockage});

  GetStorage? stockage;
  bool loading = false;
  List<ServiceModel> services = [];
  ServiceModel? currentService;

  // Récupérer tous les services
  Future<void> fetchServices() async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.services}";
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic>) {
        dynamic servicesData;

        if (response.containsKey('services')) {
          servicesData = response['services'];
        } else if (response.containsKey('data')) {
          servicesData = response['data'];
        } else {
          servicesData = response;
        }

        if (servicesData is List && servicesData.isNotEmpty) {
          services = servicesData
              .where((e) => e != null)
              .map<ServiceModel>((e) {
            try {
              return ServiceModel.fromJson(e);
            } catch (e) {
              print("Erreur lors du parsing d'un service: $e");
              return ServiceModel();
            }
          })
              .where((service) => service.serviceId != null)
              .toList();
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération des services: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Récupérer un service par ID
  Future<ServiceModel?> fetchServiceById(int serviceId) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.serviceDetail}$serviceId";
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic>) {
        currentService = ServiceModel.fromJson(response);
        return currentService;
      }
    } catch (e) {
      print("Erreur lors de la récupération du service: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
    return null;
  }

  // Créer un nouveau service
  Future<HttpResponse> createService(Map<String, dynamic> data, {List<XFile>? images}) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.storeService}";
      
      // Si des images sont fournies, vous devrez utiliser FormData
      // Pour l'instant, on envoie juste les données JSON
      HttpResponse response = await postData(url, data);

      if (response.status == true) {
        // Recharger la liste des services
        await fetchServices();
      }

      return response;
    } catch (e) {
      print("Erreur lors de la création du service: $e");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Mettre à jour un service
  Future<HttpResponse> updateService(int serviceId, Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.updateService}$serviceId";
      HttpResponse response = await patchData(url, data);

      if (response.status == true) {
        await fetchServices();
      }

      return response;
    } catch (e) {
      print("Erreur lors de la mise à jour du service: $e");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Supprimer un service
  Future<HttpResponse> deleteService(int serviceId) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.deleteService}$serviceId";
      HttpResponse response = await deleteData(url);

      if (response.status == true) {
        services.removeWhere((s) => s.serviceId == serviceId);
      }

      return response;
    } catch (e) {
      print("Erreur lors de la suppression du service: $e");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Récupérer les services par type
  Future<void> fetchServicesByType(ServiceType type) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.servicesByType}${type.value}";
      var response = await getData(url);

      if (response != null && response is Map<String, dynamic>) {
        dynamic servicesData;

        if (response.containsKey('services')) {
          servicesData = response['services'];
        } else if (response.containsKey('data')) {
          servicesData = response['data'];
        } else {
          servicesData = response;
        }

        if (servicesData is List && servicesData.isNotEmpty) {
          services = servicesData
              .where((e) => e != null)
              .map<ServiceModel>((e) {
            try {
              return ServiceModel.fromJson(e);
            } catch (e) {
              print("Erreur lors du parsing d'un service: $e");
              return ServiceModel();
            }
          })
              .where((service) => service.serviceId != null)
              .toList();
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération des services par type: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Récupérer les services de l'utilisateur connecté
  Future<void> fetchMyServices() async {
    loading = true;
    notifyListeners();

    try {
      final token = stockage?.read<String>(StockageKeys.tokenKey) ?? '';
      final url = "${Endpoints.myServices}";
      var response = await getData(url, token: token);

      if (response != null && response is Map<String, dynamic>) {
        dynamic servicesData;

        if (response.containsKey('services')) {
          servicesData = response['services'];
        } else if (response.containsKey('data')) {
          servicesData = response['data'];
        } else {
          servicesData = response;
        }

        if (servicesData is List && servicesData.isNotEmpty) {
          services = servicesData
              .where((e) => e != null)
              .map<ServiceModel>((e) {
            try {
              return ServiceModel.fromJson(e);
            } catch (e) {
              print("Erreur lors du parsing d'un service: $e");
              return ServiceModel();
            }
          })
              .where((service) => service.serviceId != null)
              .toList();
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération de mes services: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

