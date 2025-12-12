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

  // Récupérer le type de compte de l'utilisateur connecté
  String? _getUserTypeAccount() {
    print("🔍 [ServiceController] Début _getUserTypeAccount()");
    if (stockage == null) {
      print("❌ [ServiceController] stockage est null");
      return null;
    }
    try {
      final dynamic userData = stockage?.read(StockageKeys.userKey);
      print("📦 [ServiceController] userData récupéré: ${userData != null ? 'non null' : 'null'}");
      if (userData != null && userData is Map) {
        print("📋 [ServiceController] userData est une Map, clés: ${userData.keys.toList()}");
        final typeAccount = userData['typeAccount'];
        print("👤 [ServiceController] typeAccount: ${typeAccount != null ? 'non null' : 'null'}");
        if (typeAccount != null && typeAccount is Map) {
          final typeName = typeAccount['name']?.toString().toLowerCase();
          print("✅ [ServiceController] Type de compte trouvé: $typeName");
          return typeName;
        } else {
          print("⚠️ [ServiceController] typeAccount n'est pas une Map ou est null");
        }
      } else {
        print("⚠️ [ServiceController] userData n'est pas une Map");
      }
    } catch (e, stackTrace) {
      print("❌ [ServiceController] Erreur lors de la récupération du type de compte: $e");
      print("📚 Stack trace: $stackTrace");
    }
    print("❌ [ServiceController] Aucun type de compte trouvé");
    return null;
  }

  // Créer un nouveau service
  Future<HttpResponse> createService(Map<String, dynamic> data, {List<XFile>? images}) async {
    print("🚀 [ServiceController] ========== DÉBUT createService ==========");
    print("📊 [ServiceController] Nombre de clés dans data: ${data.keys.length}");
    print("📋 [ServiceController] Clés dans data: ${data.keys.toList()}");
    
    loading = true;
    notifyListeners();

    try {
      // Récupérer le type de compte de l'utilisateur connecté
      print("🔍 [ServiceController] Récupération du type de compte...");
      final typeAccountName = _getUserTypeAccount();
      
      if (typeAccountName == null || typeAccountName.isEmpty) {
        print("❌ [ServiceController] Type de compte non trouvé ou vide");
        return HttpResponse(
          status: false,
          errorMsg: "Type de compte non trouvé. Veuillez vous reconnecter.",
          isException: true,
        );
      }

      // Construire l'endpoint dynamiquement : {typeAccount}s/service
      // Exemple: peintre -> peintres/service, ajusteur -> ajusteurs/service
      final typeAccountPlural = '${typeAccountName}s';
      final url = "$typeAccountPlural/service";
      
      print("🔗 [ServiceController] Endpoint de création de service: $url");
      print("📋 [ServiceController] Type de compte: $typeAccountName -> $typeAccountPlural");
      
      // Récupérer le token
      print("🔑 [ServiceController] Récupération du token...");
      final token = stockage?.read<String>(StockageKeys.tokenKey);
      if (token != null && token.isNotEmpty) {
        print("✅ [ServiceController] Token trouvé (longueur: ${token.length})");
      } else {
        print("⚠️ [ServiceController] Token non trouvé ou vide");
      }
      
      // Afficher un résumé des données (sans les images en base64 pour ne pas surcharger)
      final dataSummary = Map<String, dynamic>.from(data);
      if (dataSummary.containsKey('images') && dataSummary['images'] is List) {
        final imagesList = dataSummary['images'] as List;
        dataSummary['images'] = '[${imagesList.length} images en base64]';
      }
      if (dataSummary.containsKey('realisation') && dataSummary['realisation'] is List) {
        final realisationsList = dataSummary['realisation'] as List;
        dataSummary['realisation'] = '[${realisationsList.length} réalisations]';
      }
      print("📦 [ServiceController] Données à envoyer (résumé): $dataSummary");
      
      // Si des images sont fournies, vous devrez utiliser FormData
      // Pour l'instant, on envoie juste les données JSON
      print("📡 [ServiceController] Appel à postData avec URL: $url");
      print("⏳ [ServiceController] En attente de la réponse...");
      
      final startTime = DateTime.now();
      HttpResponse response = await postData(url, data, token: token);
      final duration = DateTime.now().difference(startTime);
      
      print("⏱️ [ServiceController] Réponse reçue après ${duration.inMilliseconds}ms");
      print("📥 [ServiceController] Status de la réponse: ${response.status}");
      print("📥 [ServiceController] errorMsg: ${response.errorMsg ?? 'null'}");
      print("📥 [ServiceController] isException: ${response.isException}");
      
      if (response.data != null) {
        print("📥 [ServiceController] Response.data existe");
        if (response.data is Map) {
          final responseData = response.data as Map;
          print("📥 [ServiceController] Response.data clés: ${responseData.keys.toList()}");
          if (responseData.containsKey('message')) {
            print("📥 [ServiceController] Message: ${responseData['message']}");
          }
          if (responseData.containsKey('error')) {
            print("❌ [ServiceController] Erreur dans response.data: ${responseData['error']}");
          }
        } else {
          print("📥 [ServiceController] Response.data type: ${response.data.runtimeType}");
        }
      } else {
        print("⚠️ [ServiceController] Response.data est null");
      }

      if (response.status == true) {
        print("✅ [ServiceController] Service créé avec succès, rechargement de la liste...");
        // Recharger la liste des services
        await fetchServices();
        print("✅ [ServiceController] Liste des services rechargée");
      } else {
        print("❌ [ServiceController] Échec de la création du service");
      }

      print("🏁 [ServiceController] ========== FIN createService ==========");
      return response;
    } catch (e, stackTrace) {
      print("❌ [ServiceController] ========== EXCEPTION dans createService ==========");
      print("❌ [ServiceController] Erreur: $e");
      print("📚 [ServiceController] Stack trace: $stackTrace");
      print("🏁 [ServiceController] ========== FIN createService (avec erreur) ==========");
      return HttpResponse(
        status: false,
        errorMsg: e.toString(),
        isException: true,
      );
    } finally {
      loading = false;
      notifyListeners();
      print("🔄 [ServiceController] loading mis à false, notifyListeners() appelé");
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

