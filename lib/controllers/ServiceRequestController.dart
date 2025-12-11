import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../models/ServiceRequestModel.dart';
import '../models/ServiceRequestResponseModel.dart';
import '../utils/Endpoints.dart';
import '../utils/StockageKeys.dart';
import '../utils/requetes.dart' show getData, postData, putData, deleteData, HttpResponse;

class ServiceRequestController with ChangeNotifier {
  ServiceRequestController({this.stockage});

  GetStorage? stockage;
  bool loading = false;
  List<ServiceRequestModel> requests = [];
  List<ServiceRequestModel> providerRequests = [];
  ServiceRequestModel? currentRequest;

  // Récupérer les demandes de l'utilisateur connecté (demandeur)
  Future<void> fetchUserRequests() async {
    loading = true;
    notifyListeners();

    try {
      final url = Endpoints.getServiceRequests;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      var response = await getData(url, token: tkn);

      if (response != null && response is Map<String, dynamic>) {
        dynamic requestsData;

        if (response.containsKey('requests')) {
          requestsData = response['requests'];
        } else if (response.containsKey('data')) {
          requestsData = response['data'];
        } else if (response is List) {
          requestsData = response;
        }

        if (requestsData is List && requestsData.isNotEmpty) {
          requests = requestsData
              .where((e) => e != null)
              .map<ServiceRequestModel>((e) {
            try {
              return ServiceRequestModel.fromJson(e);
            } catch (e) {
              print("Erreur lors du parsing d'une demande: $e");
              return ServiceRequestModel();
            }
          })
              .where((request) => request.requestId != null)
              .toList();
        } else {
          requests = [];
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération des demandes: $e");
      requests = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Récupérer les demandes disponibles pour les prestataires
  Future<void> fetchProviderRequests() async {
    loading = true;
    notifyListeners();

    try {
      final url = Endpoints.getServiceRequestsForProviders;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      var response = await getData(url, token: tkn);

      if (response != null && response is Map<String, dynamic>) {
        dynamic requestsData;

        if (response.containsKey('requests')) {
          requestsData = response['requests'];
        } else if (response.containsKey('data')) {
          requestsData = response['data'];
        } else if (response is List) {
          requestsData = response;
        }

        if (requestsData is List && requestsData.isNotEmpty) {
          providerRequests = requestsData
              .where((e) => e != null)
              .map<ServiceRequestModel>((e) {
            try {
              return ServiceRequestModel.fromJson(e);
            } catch (e) {
              print("Erreur lors du parsing d'une demande: $e");
              return ServiceRequestModel();
            }
          })
              .where((request) => request.requestId != null)
              .toList();
        } else {
          providerRequests = [];
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération des demandes prestataires: $e");
      providerRequests = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Récupérer une demande par ID
  Future<ServiceRequestModel?> fetchRequestById(int requestId) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.serviceRequestDetail}$requestId";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      var response = await getData(url, token: tkn);

      if (response != null && response is Map<String, dynamic>) {
        currentRequest = ServiceRequestModel.fromJson(response);
        return currentRequest;
      }
    } catch (e) {
      print("Erreur lors de la récupération de la demande: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
    return null;
  }

  // Créer une nouvelle demande
  Future<HttpResponse> createServiceRequest({
    required String serviceType,
    required String message,
    bool isUrgent = false,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final url = Endpoints.createServiceRequest;
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      
      final data = {
        "serviceType": serviceType,
        "message": message,
        "isUrgent": isUrgent,
        if (latitude != null) "latitude": latitude,
        if (longitude != null) "longitude": longitude,
        if (address != null) "address": address,
      };

      HttpResponse response = await postData(url, data, token: tkn);

      if (response.status == true) {
        // Recharger la liste des demandes
        await fetchUserRequests();
      }

      return response;
    } catch (e) {
      print("Erreur lors de la création de la demande: $e");
      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors de la création de la demande: $e",
        isException: true,
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Répondre à une demande (prestataire)
  Future<HttpResponse> respondToRequest({
    required int requestId,
    required String message,
    double? price,
    String? estimatedTime,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.respondToRequest}/$requestId/respond";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);
      
      final data = {
        "message": message,
        if (price != null) "price": price,
        if (estimatedTime != null) "estimatedTime": estimatedTime,
      };

      HttpResponse response = await postData(url, data, token: tkn);

      if (response.status == true) {
        // Recharger les détails de la demande
        await fetchRequestById(requestId);
        // Recharger la liste des demandes prestataires
        await fetchProviderRequests();
      }

      return response;
    } catch (e) {
      print("Erreur lors de la réponse à la demande: $e");
      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors de la réponse: $e",
        isException: true,
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Accepter une réponse (demandeur)
  Future<HttpResponse> acceptResponse({
    required int requestId,
    required int responseId,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.acceptResponse}/$requestId/accept/$responseId";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await putData(url, {}, token: tkn);

      if (response.status == true) {
        // Recharger les détails de la demande
        await fetchRequestById(requestId);
        // Recharger la liste des demandes
        await fetchUserRequests();
      }

      return response;
    } catch (e) {
      print("Erreur lors de l'acceptation de la réponse: $e");
      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors de l'acceptation: $e",
        isException: true,
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Annuler une demande
  Future<HttpResponse> cancelRequest(int requestId) async {
    loading = true;
    notifyListeners();

    try {
      final url = "${Endpoints.cancelRequest}/$requestId";
      final tkn = stockage?.read<String>(StockageKeys.tokenKey);

      HttpResponse response = await deleteData(url, token: tkn);

      if (response.status == true) {
        // Recharger la liste des demandes
        await fetchUserRequests();
      }

      return response;
    } catch (e) {
      print("Erreur lors de l'annulation de la demande: $e");
      return HttpResponse(
        status: false,
        errorMsg: "Erreur lors de l'annulation: $e",
        isException: true,
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

